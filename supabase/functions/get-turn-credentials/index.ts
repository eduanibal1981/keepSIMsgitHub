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

async function generateIceServers(userId: string): Promise<{ iceServers: any[]; hasTurn: boolean }> {
  const servers: any[] = [
    { urls: ["stun:34.40.33.208:3478", "stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"] },
  ];

  const turnHost = Deno.env.get("TURN_HOST") || Deno.env.get("COTURN_HOST") || "34.40.33.208";
  const turnSecret = Deno.env.get("TURN_SHARED_SECRET") || Deno.env.get("COTURN_SHARED_SECRET") || "keepsims_turn_secret_2026_prod";

  // 1. Dynamic RFC 5766 HMAC-SHA1 Ephemeral Credentials (Coturn / RFC 5766)
  if (turnHost && turnSecret) {
    const ttlSeconds = 14400; // 4 hours standard ephemeral token lifetime
    const expiry = Math.floor(Date.now() / 1000) + ttlSeconds;
    const username = `${expiry}:${userId}`;

    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(turnSecret),
      { name: "HMAC", hash: "SHA-1" },
      false,
      ["sign"],
    );
    const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(username));
    const credential = btoa(String.fromCharCode(...new Uint8Array(signature)));

    const udpPort = Deno.env.get("TURN_PORT") || "3478";
    const tlsPort = Deno.env.get("TURN_TLS_PORT") || "443";

    servers.push({
      urls: [
        `turn:${turnHost}:${udpPort}?transport=udp`,
        `turn:${turnHost}:${udpPort}?transport=tcp`,
        `turns:${turnHost}:${tlsPort}?transport=tcp`,
      ],
      username,
      credential,
    });
    return { iceServers: servers, hasTurn: true };
  }

  // 2. Static TURN configuration fallback
  const turnUrls = Deno.env.get("TURN_URLS");
  const turnUsername = Deno.env.get("TURN_USERNAME");
  const turnCredential = Deno.env.get("TURN_CREDENTIAL");

  if (turnUrls && turnUsername && turnCredential) {
    servers.push({
      urls: turnUrls.split(",").map((u) => u.trim()),
      username: turnUsername,
      credential: turnCredential,
    });
    return { iceServers: servers, hasTurn: true };
  }

  // 3. Open Relay fallback for testing and development
  const disableOpenRelay = Deno.env.get("DISABLE_OPENRELAY") === "true";
  if (!disableOpenRelay) {
    servers.push({
      urls: [
        "turn:global.relay.metered.ca:80",
        "turn:global.relay.metered.ca:443",
        "turn:global.relay.metered.ca:443?transport=tcp",
        "turns:global.relay.metered.ca:443?transport=tcp",
      ],
      username: "openrelayproject",
      credential: "openrelayproject",
    });
    return { iceServers: servers, hasTurn: true };
  }

  return { iceServers: servers, hasTurn: false };
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

    const { iceServers, hasTurn } = await generateIceServers(userId);

    return jsonResponse({
      ok: true,
      call_id: call_id,
      has_turn: hasTurn,
      ice_servers: iceServers,
    }, 200);
  } catch (err: any) {
    return jsonResponse({ error: err?.message || String(err) }, 500);
  }
});
