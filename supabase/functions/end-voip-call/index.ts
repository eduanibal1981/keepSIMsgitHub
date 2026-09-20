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

    // 1. Fetch current session
    const sessionRes = await fetch(
      `${SUPABASE_URL}/rest/v1/voip_call_sessions?id=eq.${call_id}&select=*`,
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

    // 2. Calculate duration
    const now = new Date();
    let durationSeconds = 0;
    if (session.connected_at) {
      const connected = new Date(session.connected_at);
      durationSeconds = Math.max(0, Math.floor((now.getTime() - connected.getTime()) / 1000));
    }

    // 3. Update session
    const updatePayload: Record<string, unknown> = {
      status,
      end_reason,
      ended_at: now.toISOString(),
      duration_seconds: durationSeconds,
      updated_at: now.toISOString(),
    };

    const updateRes = await fetch(
      `${SUPABASE_URL}/rest/v1/voip_call_sessions?id=eq.${call_id}`,
      {
        method: "PATCH",
        headers: { ...serviceHeaders, "Prefer": "return=representation" },
        body: JSON.stringify(updatePayload),
      }
    );

    if (!updateRes.ok) {
      const err = await updateRes.text();
      return jsonResponse({ error: `Update failed: ${err}` }, 500);
    }

    const updated = await updateRes.json();

    return jsonResponse({
      ok: true,
      call_id,
      status,
      duration_seconds: durationSeconds,
      session: updated?.[0] || null,
    }, 200);
  } catch (err: any) {
    return jsonResponse({ error: err?.message || String(err) }, 500);
  }
});
