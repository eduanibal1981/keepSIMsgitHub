import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// Inbound SMS webhook — offline-recharge fallback #2 (C4). When the user has no
// data (so WhatsApp can't send) but the cellular network is up, they text
// "REFILL" to our SMS number. Shaped for a Twilio Messaging webhook
// (application/x-www-form-urlencoded: From, Body, MessageSid) but any provider
// that posts those fields works.
//
// Turns the message into a wallet-funded instant refill via
// `ingest_offline_refill` (service_role only). The per-message SMS gateway cost
// is passed to the wallet as OFFLINE_SMS_MESSAGE_FEE_USD.
//
// Security: verify_jwt disabled. Validated against X-Twilio-Signature when
// TWILIO_AUTH_TOKEN is set; skipped with a warning otherwise so it works before
// provisioning. Twilio signs the EXACT public URL it requested — set
// PUBLIC_FUNCTION_URL to that URL if the reconstructed one ever mismatches.
//
// Required function secrets (once provisioned):
//   TWILIO_AUTH_TOKEN    — the Twilio account auth token (signature validation)
//   PUBLIC_FUNCTION_URL  — optional exact webhook URL override

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

// Twilio's request signature: base64( HMAC-SHA1( authToken, URL + sorted(k+v) ) ).
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

// Reconstruct the public URL Twilio signed (proxy-aware), unless overridden.
function publicUrl(req: Request): string {
  if (PUBLIC_FUNCTION_URL) return PUBLIC_FUNCTION_URL;
  const u = new URL(req.url);
  const proto = req.headers.get('x-forwarded-proto') ?? u.protocol.replace(':', '');
  const host = req.headers.get('x-forwarded-host') ?? req.headers.get('host') ?? u.host;
  return `${proto}://${host}${u.pathname}${u.search}`;
}

function parseAmount(text: string | undefined): number | null {
  if (!text) return null;
  const m = text.match(/(\d+(?:\.\d{1,2})?)/);
  if (!m) return null;
  const n = Number(m[1]);
  return Number.isFinite(n) && n > 0 && n <= 500 ? n : null;
}

serve(async (req: Request) => {
  if (req.method !== 'POST') return twiml('');

  const raw = await req.text();
  const form = new URLSearchParams(raw);
  const params: Record<string, string> = {};
  for (const [k, v] of form.entries()) params[k] = v;

  if (TWILIO_AUTH_TOKEN) {
    const expected = await twilioSignature(publicUrl(req), params);
    const header = req.headers.get('x-twilio-signature') ?? '';
    if (!safeEqual(header, expected)) {
      console.error('sms-webhook: Twilio signature mismatch');
      return new Response('Forbidden', { status: 403 });
    }
  } else {
    console.warn('sms-webhook: TWILIO_AUTH_TOKEN unset — skipping signature check');
  }

  const from = params['From'];
  const body = params['Body'];
  const msgId = params['MessageSid'] || params['SmsSid'];

  if (from && msgId) {
    const { ok, status, body: out } = await rpc('ingest_offline_refill', {
      p_provider: 'sms',
      p_provider_msg_id: msgId,
      p_sender_phone: from,
      p_channel: 'sms',
      p_amount_usd: parseAmount(body),
      p_raw: params,
    });
    if (!ok) console.error(`ingest_offline_refill HTTP ${status}: ${JSON.stringify(out)}`);
  } else {
    console.error('sms-webhook: missing From/MessageSid', params);
  }

  // Empty TwiML: acknowledge without sending a (billable) auto-reply. The app
  // confirms the outcome in-app on reconnect via the topup_executions stream.
  return twiml('');
});
