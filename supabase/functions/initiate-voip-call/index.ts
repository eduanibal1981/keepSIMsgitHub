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
    const callerId = await resolveUserId(req);
    if (!callerId) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const { callee_id, offer_sdp, caller_device_id } = await req.json();
    if (!callee_id) {
      return jsonResponse({ error: "Missing callee_id" }, 400);
    }

    if (callerId === callee_id) {
      return jsonResponse({ error: "Cannot call yourself" }, 400);
    }

    const { iceServers, hasTurn } = await generateIceServers(
      createClient(SUPABASE_URL, SERVICE_ROLE_KEY), callerId,
    );

    // 1. Fetch Caller Profile
    const callerRes = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?id=eq.${callerId}&select=full_name,avatar_url,phone`,
      { headers: serviceHeaders }
    );
    const callerRows = await callerRes.json();
    const callerProfile = callerRows?.[0] || { full_name: "KeepSIMs User", avatar_url: null, phone: null };

    // 2. Fetch Callee Profile
    const calleeRes = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?id=eq.${callee_id}&select=id,full_name,avatar_url,phone`,
      { headers: serviceHeaders }
    );
    const calleeRows = await calleeRes.json();
    if (!calleeRows || calleeRows.length === 0) {
      return jsonResponse({ error: "Callee not found" }, 404);
    }
    const calleeProfile = calleeRows[0];

    // 3. Check if Callee is already in an active call (ignore stale sessions > 60s)
    const activeCheckRes = await fetch(
      `${SUPABASE_URL}/rest/v1/voip_call_sessions?or=(callee_id.eq.${callee_id},caller_id.eq.${callee_id})&status=in.(initiating,ringing,accepted)&select=id,status,created_at`,
      { headers: serviceHeaders }
    );
    const activeCalls = await activeCheckRes.json();
    if (activeCalls && activeCalls.length > 0) {
      const now = Date.now();
      const genuineActiveCalls = activeCalls.filter((c: any) => {
        const createdAt = new Date(c.created_at).getTime();
        return (now - createdAt) < 60000;
      });
      if (genuineActiveCalls.length > 0) {
        return jsonResponse({
          status: "busy",
          message: "User is currently on another call.",
        }, 200);
      }
    }

    // 4. Create Call Session
    const sessionRes = await fetch(`${SUPABASE_URL}/rest/v1/voip_call_sessions`, {
      method: "POST",
      headers: { ...serviceHeaders, "Prefer": "return=representation" },
      body: JSON.stringify({
        caller_id: callerId,
        callee_id: callee_id,
        call_type: "voice",
        status: "initiating",
        offer_sdp: offer_sdp || null,
        caller_device_id: caller_device_id || null,
      }),
    });

    if (!sessionRes.ok) {
      const errText = await sessionRes.text();
      return jsonResponse({ error: `Failed to create session: ${errText}` }, 500);
    }

    const sessionData = await sessionRes.json();
    const callSession = sessionData[0];
    const callId = callSession.id;

    // 5. Fetch Callee Push Tokens
    const voipTokensRes = await fetch(
      `${SUPABASE_URL}/rest/v1/voip_push_tokens?user_id=eq.${callee_id}&is_active=eq.true&select=device_id,platform,voip_token,fcm_token`,
      { headers: serviceHeaders }
    );
    const voipTokens = await voipTokensRes.json();

    // Fallback: check device_push_tokens if no voip_push_tokens exist yet
    let fallbackFcmTokens: string[] = [];
    if (!voipTokens || voipTokens.length === 0) {
      const legacyTokensRes = await fetch(
        `${SUPABASE_URL}/rest/v1/device_push_tokens?user_id=eq.${callee_id}&select=device_id,fcm_token`,
        { headers: serviceHeaders }
      );
      const legacyTokens = await legacyTokensRes.json();
      if (legacyTokens && legacyTokens.length > 0) {
        fallbackFcmTokens = legacyTokens
          .map((t: any) => t.fcm_token)
          .filter((t: any) => typeof t === "string" && t.length > 0);
      }
    }

    // 6. Asynchronously dispatch push notification to wake up recipient
    // (Both FCM high-priority data message for Android and APNs VoIP for iOS)
    const pushPayload = {
      type: "INCOMING_VOIP_CALL",
      call_id: callId,
      caller_id: callerId,
      caller_name: callerProfile.full_name || "KeepSIMs User",
      caller_avatar: callerProfile.avatar_url || "",
      caller_phone: callerProfile.phone || "",
      created_at: new Date().toISOString(),
    };

    // Dispatch FCM data messages if FCM tokens are present
    const fcmTokensToTarget = [
      ...(voipTokens || []).map((t: any) => t.fcm_token).filter(Boolean),
      ...fallbackFcmTokens,
    ];

    // Trigger internal dispatch if configured
    if (fcmTokensToTarget.length > 0) {
      try {
        await fetch(`${SUPABASE_URL}/functions/v1/dispatch-alert`, {
          method: "POST",
          headers: serviceHeaders,
          body: JSON.stringify({
            category: "voip_call",
            user_id: callee_id,
            voip_payload: pushPayload,
            fcm_tokens: fcmTokensToTarget,
          }),
        }).catch(() => {});
      } catch (_) {
        // Continue even if push dispatch notification fails; Realtime will also alert if app is open
      }
    }



    return jsonResponse({
      ok: true,
      call_id: callId,
      status: "initiating",
      has_turn: hasTurn,
      ice_servers: iceServers,
      callee: {
        id: calleeProfile.id,
        name: calleeProfile.full_name,
        avatar: calleeProfile.avatar_url,
        phone: calleeProfile.phone,
      },
    }, 200);
  } catch (err: any) {
    if (err instanceof ProviderConfigurationError) {
      return jsonResponse({ error: err.message, code: err.code }, 503);
    }
    return jsonResponse({ error: "Unable to prepare call connectivity." }, 500);
  }
});
