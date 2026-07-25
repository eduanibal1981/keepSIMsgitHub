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

    if (!userId) {
      return new Response(
        JSON.stringify({ success: false, error: "BAD_REQUEST: Missing user_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Refuse any user_id whose account_deletions.status <> 'purged'
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

    // 2. Delete user_preferences (no FK, must delete manually)
    await adminClient.from("user_preferences").delete().eq("user_id", userId);

    // 3. Delete auth user via direct SQL (bypasses GoTrue "Database error loading user" bug)
    // The service_role key allows SQL execution via the rpc endpoint.
    const { error: deleteError } = await adminClient.rpc("delete_auth_user_by_id", {
      p_user_id: userId,
    });

    if (deleteError) {
      console.error("delete_auth_user_by_id failed:", deleteError);
      // Fall back to Auth Admin REST API
      const deleteRes = await fetch(`${supabaseUrl}/auth/v1/admin/users/${userId}`, {
        method: "DELETE",
        headers: {
          "apikey": supabaseServiceKey,
          "Authorization": `Bearer ${supabaseServiceKey}`,
          "Content-Type": "application/json",
        },
      });

      if (!deleteRes.ok && deleteRes.status !== 404) {
        const errText = await deleteRes.text();
        console.error("Auth admin REST fallback failed:", errText);
        // Still mark as auth_deleted if user doesn't exist anymore
        const { data: userCheck } = await adminClient.rpc("check_auth_user_exists", {
          p_user_id: userId,
        });
        if (userCheck === true) {
          return new Response(
            JSON.stringify({ success: false, error: `Auth deletion failed: ${errText}` }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }
    }

    // 4. Mark account_deletions row as auth_deleted
    const { error: updateErr } = await adminClient
      .from("account_deletions")
      .update({
        status: "auth_deleted",
        auth_deleted_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", userId);

    if (updateErr) {
      console.error("Failed to update account_deletions:", updateErr);
    }

    return new Response(
      JSON.stringify({ success: true, user_id: userId, status: "auth_deleted" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ success: false, error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
