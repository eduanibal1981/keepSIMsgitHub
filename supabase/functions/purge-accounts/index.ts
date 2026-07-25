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
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Verify Vault secret header or service_role authorization
    const incomingSecret = req.headers.get("x-keep-sims-secret");
    const { data: secretData } = await adminClient.rpc("get_internal_secret", {
      p_name: "dispatch_shared_secret",
    });

    const expectedSecret = secretData || "";
    if (expectedSecret && incomingSecret !== expectedSecret) {
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

    // 1. Storage Objects Cleanup across buckets
    const buckets = ["ticket-attachments", "support_attachments"];
    for (const bucketName of buckets) {
      try {
        const { data: files } = await adminClient.storage.from(bucketName).list(userId);
        if (files && files.length > 0) {
          const filePaths = files.map((f) => `${userId}/${f.name}`);
          await adminClient.storage.from(bucketName).remove(filePaths);
        }
      } catch (_) {
        // Continue if bucket not configured
      }
    }

    // 2. Auth User Admin Deletion
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
    if (deleteError) {
      return new Response(
        JSON.stringify({ success: false, error: deleteError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Mark account_deletions row as auth_deleted
    await adminClient
      .from("account_deletions")
      .update({
        status: "auth_deleted",
        auth_deleted_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", userId);

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
