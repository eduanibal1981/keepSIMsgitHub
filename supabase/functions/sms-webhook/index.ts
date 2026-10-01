import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// Inbound SMS webhook — offline-recharge fallback #2 (C4), plus the G9 command
// router. When the user has no data (so WhatsApp can't send) but the cellular
// network is up, they text us. Shaped for a Twilio Messaging webhook
// (application/x-www-form-urlencoded: From, Body, MessageSid) but any provider
// that posts those fields works.
//
// G9: the body is now CLASSIFIED before anything happens. Until G9 this handler
// passed every inbound message straight to `ingest_offline_refill`, which read
// the body only through a regex for the first number — so "hi", "stop" and
// "BAL" all fell through to the user's default_refill_amount and queued a $10
// top-up. `handle_inbound_command` decides what was asked for, does it, and
// returns the text to reply with; only REFILL or a bare amount spends money.
//
// The reply rides back in the TwiML response, which costs nothing extra and
// needs no outbound credentials — Twilio sends whatever <Message> we return.
//
// D2 IP Rate Limiter applied (60/1min per IP); G9 adds a 10/60min per-sender
// limit inside the database.

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

const twiml = (inner: string) =>
  new Response(`<?xml version="1.0" encoding="UTF-8"?><Response>${inner}</Response>`, {
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

// XML-escape the reply. The body is server-authored, but it interpolates a
// user-chosen SIM nickname, so it is not trusted to be XML-safe.
function xmlEscape(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

serve(async (req: Request) => {
  if (req.method !== 'POST') return twiml('');
  if (!TWILIO_AUTH_TOKEN) return new Response('Webhook authentication is not configured', { status: 503 });
  if (!req.headers.get('x-twilio-signature')) return new Response('Forbidden', { status: 403 });

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

  {
    const expected = await twilioSignature(publicUrl(req), params);
    const header = req.headers.get('x-twilio-signature') ?? '';
    if (!safeEqual(header, expected)) {
      console.error('sms-webhook: Twilio signature mismatch');
      return new Response('Forbidden', { status: 403 });
    }
  }

  const from = params['From'];
  const body = params['Body'];
  const msgId = params['MessageSid'] || params['SmsSid'];

  if (!from || !msgId) {
    console.error('sms-webhook: missing From/MessageSid', params);
    return new Response('Missing sender or message ID', { status: 400 });
  }

  const { ok, status, body: out } = await rpc('handle_inbound_command', {
    p_provider: 'sms',
    p_provider_msg_id: msgId,
    p_sender_phone: from,
    p_channel: 'sms',
    p_body: body ?? '',
    p_raw: params,
  });

  if (!ok) {
    console.error(`handle_inbound_command HTTP ${status}: ${JSON.stringify(out)}`);
    return new Response('Command processing temporarily unavailable', { status: 503 });
  }

  // An unknown sender, or one over the per-sender limit, returns no reply text
  // on purpose: answering would turn this number into an oracle for "is this
  // phone a KeepSIMs user?" and bill us for an SMS to a stranger.
  const reply = (out as Record<string, unknown> | null)?.['reply_text'];
  if (typeof reply === 'string' && reply.length > 0) {
    return twiml(`<Message>${xmlEscape(reply)}</Message>`);
  }

  return twiml('');
});
