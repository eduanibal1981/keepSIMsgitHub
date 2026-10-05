import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const resendKey = Deno.env.get("RESEND_API_KEY");
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function response(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function digest(userId: string, email: string, code: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(serviceKey),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const bytes = new Uint8Array(await crypto.subtle.sign(
    "HMAC", key, new TextEncoder().encode(`${userId}:${email.trim().toLowerCase()}:${code}`),
  ));
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function makeCode(): string {
  const range = 90_000_000;
  const cutoff = Math.floor(0x1_0000_0000 / range) * range;
  const value = new Uint32Array(1);
  do crypto.getRandomValues(value);
  while (value[0] >= cutoff);
  return String(10_000_000 + (value[0] % range));
}

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return response(405, { error: "Method not allowed." });

  const authorization = request.headers.get("Authorization");
  const accessToken = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!accessToken) return response(401, { error: "Please sign in again." });

  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser(accessToken);
  if (authError || !authData.user) return response(401, { error: "Please sign in again." });

  const user = authData.user;
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (_) {
    return response(400, { error: "Invalid request." });
  }

  if (body.action === "status") {
    const [{ data: destination, error: destinationError }, { data: challenge, error: challengeError }] = await Promise.all([
      admin.from("notification_email_destinations").select("email,verified_at").eq("user_id", user.id).maybeSingle(),
      admin.from("notification_email_verification_challenges").select("email,expires_at").eq("user_id", user.id).maybeSingle(),
    ]);
    if (destinationError || challengeError) return response(500, { error: "Email settings could not be loaded." });
    const accountVerified = !!user.email && !!user.email_confirmed_at;
    const alternate = typeof destination?.email === "string" ? destination.email : null;
    return response(200, {
      account_email: user.email ?? null,
      account_email_verified: accountVerified,
      current_email: alternate ?? (accountVerified ? user.email : null),
      alternate_email: alternate,
      pending_email: challenge && Date.parse(challenge.expires_at) > Date.now() ? challenge.email : null,
    });
  }

  if (body.action === "use_account_email") {
    if (!user.email || !user.email_confirmed_at) {
      return response(400, { error: "Confirm your account email before using it for alerts." });
    }
    const { error } = await admin.from("notification_email_destinations").delete().eq("user_id", user.id);
    if (error) return response(500, { error: "The alert address could not be changed." });
    await admin.from("notification_email_verification_challenges").delete().eq("user_id", user.id);
    return response(200, { success: true });
  }

  if (body.action === "request_code") {
    const email = typeof body.email === "string" ? body.email.trim() : "";
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return response(400, { error: "Enter a valid email address." });
    }
    if (user.email && email.toLowerCase() === user.email.toLowerCase()) {
      return response(400, { error: "Use the account email option for this address." });
    }
    if (!resendKey) return response(503, { error: "Email verification is temporarily unavailable." });

    const now = new Date();
    const code = makeCode();
    const codeDigest = await digest(user.id, email, code);
    const { data: requestAllowed, error: saveError } = await admin.rpc(
      "begin_notification_email_verification",
      {
        p_user_id: user.id,
        p_email: email,
        p_code_digest: codeDigest,
        p_expires_at: new Date(now.getTime() + 10 * 60_000).toISOString(),
      },
    );
    if (saveError) return response(500, { error: "A verification code could not be sent." });
    if (requestAllowed !== true) {
      return response(429, { error: "Too many codes were requested. Wait a minute or try again in an hour." });
    }

    const mail = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${resendKey}` },
      body: JSON.stringify({
        from: "KeepSIMs <alerts@keepsims.com>",
        to: email,
        subject: "Verify your KeepSIMs alert email",
        html: `<div style="font-family:sans-serif"><h2>Verify this email for KeepSIMs alerts</h2><p>Your verification code is:</p><p style="font-size:28px;font-weight:700;letter-spacing:4px">${code}</p><p>This code expires in 10 minutes. Alerts will continue going to your current verified address until you confirm this one.</p><p>If you did not request this, you can ignore this email.</p></div>`,
      }),
      signal: AbortSignal.timeout(10_000),
    }).catch(() => null);
    if (!mail?.ok) {
      return response(502, { error: "The verification email could not be sent. Try again shortly." });
    }
    return response(200, { success: true });
  }

  if (body.action === "confirm_code") {
    const code = typeof body.code === "string" ? body.code.trim() : "";
    if (!/^\d{8}$/.test(code)) return response(400, { error: "Enter the 8-digit code." });
    const { data: challenge, error: lookupError } = await admin
      .from("notification_email_verification_challenges")
      .select("email,expires_at,attempt_count")
      .eq("user_id", user.id).maybeSingle();
    if (lookupError) return response(500, { error: "The code could not be checked." });
    if (!challenge || Date.parse(challenge.expires_at) <= Date.now() || challenge.attempt_count >= 5) {
      return response(400, { error: "This code is invalid or expired. Request a new one." });
    }
    const codeDigest = await digest(user.id, challenge.email, code);
    const { data: result, error } = await admin.rpc("consume_notification_email_verification", {
      p_user_id: user.id,
      p_code_digest: codeDigest,
    });
    if (error) return response(500, { error: "The code could not be checked." });
    if (result?.valid !== true) return response(400, { error: "This code is invalid or expired. Request a new one." });
    return response(200, { success: true, email: result.email });
  }

  return response(400, { error: "Unknown verification action." });
});
