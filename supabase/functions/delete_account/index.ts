import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "UNAUTHORIZED: Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const client = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    const { data: { user }, error: userError } = await client.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: "UNAUTHORIZED: Invalid user token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Freshness check: last_sign_in_at must be within 15 minutes
    if (user.last_sign_in_at) {
      const lastSignIn = new Date(user.last_sign_in_at).getTime();
      const now = Date.now();
      if (now - lastSignIn > 15 * 60 * 1000) {
        return new Response(
          JSON.stringify({ success: false, code: "REAUTH_REQUIRED", error: "Session expired. Please re-authenticate before requesting account deletion." }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    let reason: string | null = null;
    let forfeitDust = false;

    if (req.method === "POST") {
      try {
        const body = await req.json();
        reason = body.reason || null;
        forfeitDust = Boolean(body.forfeit_dust);
      } catch (_) {
        // Body optional
      }
    }

    const { data, error } = await client.rpc("request_account_deletion", {
      p_reason: reason,
      p_forfeit_dust: forfeitDust,
    });

    if (error) {
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Global session revocation on freeze
    if (data && data.success) {
      try {
        await adminClient.auth.admin.signOut(user.id, "global");
      } catch (_) {
        // Ignore signout error if session already cleared
      }
    }

    return new Response(
      JSON.stringify(data),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ success: false, error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
