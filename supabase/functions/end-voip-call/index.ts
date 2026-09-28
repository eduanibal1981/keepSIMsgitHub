import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

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

    const { call_id, status = "completed", end_reason = "normal_hangup" } = await req.json();
    if (!call_id) {
      return jsonResponse({ error: "Missing call_id" }, 400);
    }

    // 1. Fetch current session to verify authorization
    const sessionRes = await fetch(
      `${SUPABASE_URL}/rest/v1/voip_call_sessions?id=eq.${call_id}&select=id,caller_id,callee_id,status,connected_at`,
      { headers: serviceHeaders }
    );
    const sessionRows = await sessionRes.json();
    if (!sessionRows || sessionRows.length === 0) {
      return jsonResponse({ error: "Session not found" }, 404);
    }
    const session = sessionRows[0];

    // Ensure requesting user is a participant
    if (session.caller_id !== userId && session.callee_id !== userId) {
      return jsonResponse({ error: "Forbidden" }, 403);
    }

    // Terminal state guard: if already in a terminal state, return existing state
    const terminalStates = ["completed", "declined", "busy", "missed", "failed", "timeout"];
    if (terminalStates.includes(session.status)) {
      return jsonResponse({
        ok: true,
        call_id,
        status: session.status,
        already_terminated: true,
        duration_seconds: 0,
      }, 200);
    }

    // 2. Invoke atomic terminate_voip_session RPC
    const rpcRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/terminate_voip_session`, {
      method: "POST",
      headers: serviceHeaders,
      body: JSON.stringify({
        p_call_id: call_id,
        p_status: status,
        p_end_reason: end_reason,
      }),
    });

    if (!rpcRes.ok) {
      const err = await rpcRes.text();
      return jsonResponse({ error: `Termination RPC failed: ${err}` }, 500);
    }

    const rpcResult = await rpcRes.json();

    return jsonResponse({
      ok: true,
      call_id,
      status: rpcResult?.status || status,
      duration_seconds: rpcResult?.duration_seconds ?? 0,
      result: rpcResult,
    }, 200);
  } catch (err: any) {
    return jsonResponse({ error: err?.message || String(err) }, 500);
  }
});
