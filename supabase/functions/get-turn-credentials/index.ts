import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { ProviderConfigurationError } from "../_shared/provider-secrets.ts";
import { generateIceServers } from "../_shared/turn-credentials.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const jsonResponse = (body: Record<string, unknown>, status: number) =>
  new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const serviceHeaders = {
  "apikey": SERVICE_ROLE_KEY,
  "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
  "Content-Type": "application/json",
};

async function resolveUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { "apikey": SERVICE_ROLE_KEY, "Authorization": authHeader },
  });
  if (!res.ok) return null;
  const user = await res.json();
  return user?.id ?? null;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userId = await resolveUserId(req);
    if (!userId) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const { call_id } = await req.json();
    if (!call_id) {
      return jsonResponse({ error: "Missing call_id parameter" }, 400);
    }

    // Verify requester belongs to the call session
    const sessionRes = await fetch(
      `${SUPABASE_URL}/rest/v1/voip_call_sessions?id=eq.${call_id}&select=id,caller_id,callee_id,status`,
      { headers: serviceHeaders },
    );
    const sessions = await sessionRes.json();
    if (!sessions || sessions.length === 0) {
      return jsonResponse({ error: "Call session not found" }, 404);
    }

    const session = sessions[0];
    if (session.caller_id !== userId && session.callee_id !== userId) {
      return jsonResponse({ error: "Forbidden: Not an active participant in this call" }, 403);
    }



    const { iceServers, hasTurn } = await generateIceServers(
      createClient(SUPABASE_URL, SERVICE_ROLE_KEY), userId,
    );

    return jsonResponse({
      ok: true,
      call_id: call_id,
      has_turn: hasTurn,
      ice_servers: iceServers,
    }, 200);
  } catch (err: any) {
    if (err instanceof ProviderConfigurationError) {
      return jsonResponse({ error: err.message, code: err.code }, 503);
    }
    return jsonResponse({ error: "Unable to prepare call connectivity." }, 500);
  }
});
