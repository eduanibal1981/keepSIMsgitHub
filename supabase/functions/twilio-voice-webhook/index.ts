import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// Missed-call webhook — offline-recharge fallback #3 (C4). The most robust
// channel: a plain voice call needs neither data nor SMS credit. The user rings
// our Twilio number; we reject the call before it connects (so the user is not
// charged for a call) and treat the ring itself as the refill trigger.
//
// D2 IP Rate Limiter applied (60/1min per IP).

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const TWILIO_AUTH_TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN') ?? '';
const PUBLIC_FUNCTION_URL = Deno.env.get('PUBLIC_FUNCTION_URL') ?? '';

const serviceHeaders = {
  'apikey': SERVICE_ROLE_KEY,
  'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
  'Content-Type': 'application/json',
};

async function rpc(name: string, args: Record<string, unknown>) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: serviceHeaders,
    body: JSON.stringify(args),
  });
  const text = await res.text();
  let body: unknown = text;
  try { body = JSON.parse(text); } catch (_) { /* raw text */ }
  return { ok: res.ok, status: res.status, body };
}

const rejectTwiml = () =>
  new Response(`<?xml version="1.0" encoding="UTF-8"?><Response><Reject reason="busy"/></Response>`, {
    headers: { 'Content-Type': 'text/xml' },
    status: 200,
  });

async function twilioSignature(urlStr: string, params: Record<string, string>): Promise<string> {
  let data = urlStr;
  for (const k of Object.keys(params).sort()) data += k + params[k];
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(TWILIO_AUTH_TOKEN),
    { name: 'HMAC', hash: 'SHA-1' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data));
  return btoa(String.fromCharCode(...new Uint8Array(sig)));
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function publicUrl(req: Request): string {
  if (PUBLIC_FUNCTION_URL) return PUBLIC_FUNCTION_URL;
  const u = new URL(req.url);
  const proto = req.headers.get('x-forwarded-proto') ?? u.protocol.replace(':', '');
  const host = req.headers.get('x-forwarded-host') ?? req.headers.get('host') ?? u.host;
  return `${proto}://${host}${u.pathname}${u.search}`;
}

serve(async (req: Request) => {
  if (req.method !== 'POST') return rejectTwiml();

  // D2 IP rate limiter (webhook_ip bucket: 60/1min per IP)
  const xForwardedFor = req.headers.get("x-forwarded-for");
  const clientIp = xForwardedFor ? xForwardedFor.split(",")[0].trim() : req.headers.get("x-real-ip") || "unknown_ip";

  const limitRes = await rpc('consume_rate_limit', {
    p_bucket: 'webhook_ip',
    p_key: clientIp,
    p_capacity: 60,
    p_refill_per_minute: 60.0,
  });
  if (limitRes.ok && Array.isArray(limitRes.body) && limitRes.body[0]?.allowed === false) {
    const retryAfter = limitRes.body[0]?.retry_after_seconds ?? 60;
    return new Response(JSON.stringify({ code: "rate_limited", bucket: "webhook_ip", retry_after: retryAfter }), { status: 429, headers: { 'Content-Type': 'application/json', 'Retry-After': String(retryAfter) } });
  }

  const raw = await req.text();
  const form = new URLSearchParams(raw);
  const params: Record<string, string> = {};
  for (const [k, v] of form.entries()) params[k] = v;

  if (TWILIO_AUTH_TOKEN) {
    const expected = await twilioSignature(publicUrl(req), params);
    const header = req.headers.get('x-twilio-signature') ?? '';
    if (!safeEqual(header, expected)) {
      console.error('twilio-voice-webhook: signature mismatch');
      return rejectTwiml();
    }
  } else {
    console.warn('twilio-voice-webhook: TWILIO_AUTH_TOKEN unset — skipping signature check');
  }

  const from = params['From'];
  const callSid = params['CallSid'];

  if (from && callSid) {
    const { ok, status, body: out } = await rpc('ingest_offline_refill', {
      p_provider: 'twilio',
      p_provider_msg_id: callSid,
      p_sender_phone: from,
      p_channel: 'missed_call',
      p_amount_usd: null,
      p_raw: params,
    });
    if (!ok) console.error(`ingest_offline_refill HTTP ${status}: ${JSON.stringify(out)}`);
  } else {
    console.error('twilio-voice-webhook: missing From/CallSid', params);
  }

  return rejectTwiml();
});
