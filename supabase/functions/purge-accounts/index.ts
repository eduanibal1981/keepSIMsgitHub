import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-keep-sims-secret",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Verify Vault secret header
    const incomingSecret = req.headers.get("x-keep-sims-secret");
    const { data: secretData } = await adminClient.rpc("get_internal_secret", {
      p_name: "dispatch_shared_secret",
    });

    const expectedSecret = secretData || "";
    if (!expectedSecret || incomingSecret !== expectedSecret) {
      return new Response(
        JSON.stringify({ success: false, error: "UNAUTHORIZED: Invalid secret header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    const userId = body.user_id;
    const confirmUserId = body.confirm_user_id;
    const isAdminDirectPurge = body.admin_purge === true;

    if (!userId) {
      return new Response(
        JSON.stringify({ success: false, error: "BAD_REQUEST: Missing user_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // If an admin triggers direct purge, enforce that confirm_user_id matches user_id
    if (isAdminDirectPurge) {
      if (!confirmUserId || confirmUserId !== userId) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "BAD_REQUEST: Admin direct purge requires confirm_user_id to match user_id exactly",
          }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      console.log(`[purge-accounts] Admin manual purge authorized for user: ${userId}`);
    } else {
      // Standard automated purge flow: Refuse any user_id whose account_deletions.status <> 'purged'
      const { data: deletionRecord } = await adminClient
        .from("account_deletions")
        .select("status")
        .eq("user_id", userId)
        .maybeSingle();

      if (!deletionRecord || deletionRecord.status !== "purged") {
        return new Response(
          JSON.stringify({ success: false, error: "FORBIDDEN: Account status is not purged" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 1. Storage Objects Cleanup across buckets
    const buckets = ["ticket-attachments", "support_attachments"];
    for (const bucketName of buckets) {
      try {
        const { data: files } = await adminClient.storage.from(bucketName).list(userId);
        if (files && files.length > 0) {
          const filePaths = files.map((f: any) => `${userId}/${f.name}`);
          await adminClient.storage.from(bucketName).remove(filePaths);
        }
      } catch (_) {
        // Continue if bucket not configured
      }
    }

    // 2. Auth User Admin Deletion
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
    let authDeleted = false;

    if (!deleteError) {
      authDeleted = true;
    } else {
      const status = (deleteError as any).status;
      const msg = deleteError.message || "";

      if (status === 404 || msg.includes("User not found")) {
        authDeleted = true; // Idempotent success
      } else {
        console.warn("auth.admin.deleteUser failed, attempting guarded SQL RPC fallback:", deleteError);
        const { error: rpcError } = await adminClient.rpc("delete_auth_user_by_id", {
          p_user_id: userId,
        });

        if (!rpcError) {
          authDeleted = true;
        } else {
          console.error("delete_auth_user_by_id fallback failed:", rpcError);
          const { data: userExists } = await adminClient.rpc("check_auth_user_exists", {
            p_user_id: userId,
          });
          if (userExists === false) {
            authDeleted = true;
          } else {
            return new Response(
              JSON.stringify({
                success: false,
                error: `Auth deletion failed: ${deleteError.message || rpcError.message}`,
              }),
              { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          }
        }
      }
    }

    // 3. Update or Insert account_deletions row
    if (authDeleted) {
      const { data: existingRecord } = await adminClient
        .from("account_deletions")
        .select("id")
        .eq("user_id", userId)
        .maybeSingle();

      if (existingRecord) {
        await adminClient
          .from("account_deletions")
          .update({
            status: "auth_deleted",
            auth_deleted_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", userId);
      } else if (isAdminDirectPurge) {
        await adminClient
          .from("account_deletions")
          .insert({
            user_id: userId,
            status: "auth_deleted",
            requested_at: new Date().toISOString(),
            purged_at: new Date().toISOString(),
            auth_deleted_at: new Date().toISOString(),
            de_identified_at: new Date().toISOString(),
          });
      }

      // Log in admin_audit_log if admin direct purge
      if (isAdminDirectPurge) {
        await adminClient.rpc("admin_log", {
          p_action: "user.purge_account",
          p_target_type: "user",
          p_target_id: userId,
          p_before: {},
          p_after: { status: "auth_deleted" },
          p_reason: body.reason || "Manual admin purge with user_id verification challenge",
        });
      }
    }

    return new Response(
      JSON.stringify({ success: true, user_id: userId, status: "auth_deleted", admin_purged: isAdminDirectPurge }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ success: false, error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
