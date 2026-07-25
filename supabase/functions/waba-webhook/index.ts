import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// WhatsApp Business (Cloud) API webhook — the paid-tier offline-recharge path
// (C4, PRODUCTION_PLAN.md). A user whose phone is offline sends us a WhatsApp
// message ("REFILL" or "REFILL 10"); Meta delivers it here and we turn it into
// a real, wallet-funded instant refill via `ingest_offline_refill`.
//
// D2 IP Rate Limiter applied (60/1min per IP).

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const WABA_VERIFY_TOKEN = Deno.env.get('WABA_VERIFY_TOKEN') ?? '';
const WABA_APP_SECRET = Deno.env.get('WABA_APP_SECRET') ?? '';

const serviceHeaders = {
  'apikey': SERVICE_ROLE_KEY,
  'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
  'Content-Type': 'application/json',
};

const json = (body: Record<string, unknown>, status: number) =>
  new Response(JSON.stringify(body), {
    headers: { 'Content-Type': 'application/json' },
    status,
  });

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

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function parseAmount(text: string | undefined): number | null {
  if (!text) return null;
  const m = text.match(/(\d+(?:\.\d{1,2})?)/);
  if (!m) return null;
  const n = Number(m[1]);
  return Number.isFinite(n) && n > 0 && n <= 500 ? n : null;
}

serve(async (req: Request) => {
  const url = new URL(req.url);

  if (req.method === 'GET') {
    const mode = url.searchParams.get('hub.mode');
    const token = url.searchParams.get('hub.verify_token');
    const challenge = url.searchParams.get('hub.challenge');
    if (mode === 'subscribe' && WABA_VERIFY_TOKEN && token === WABA_VERIFY_TOKEN) {
      return new Response(challenge ?? '', { status: 200 });
    }
    return new Response('Forbidden', { status: 403 });
  }

  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

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
    return json({ code: "rate_limited", bucket: "webhook_ip", retry_after: retryAfter }, 429);
  }

  const raw = await req.text();

  if (WABA_APP_SECRET) {
    const header = req.headers.get('x-hub-signature-256') ?? '';
    const expected = 'sha256=' + await hmacSha256Hex(WABA_APP_SECRET, raw);
    if (!safeEqual(header, expected)) {
      console.error('waba-webhook: signature mismatch');
      return json({ error: 'bad_signature' }, 401);
    }
  } else {
    console.warn('waba-webhook: WABA_APP_SECRET unset — skipping signature check');
  }

  let payload: any;
  try { payload = JSON.parse(raw); } catch (_) { return json({ error: 'bad_json' }, 400); }

  const results: unknown[] = [];
  try {
    const entries = Array.isArray(payload?.entry) ? payload.entry : [];
    for (const entry of entries) {
      const changes = Array.isArray(entry?.changes) ? entry.changes : [];
      for (const change of changes) {
        const value = change?.value ?? {};
        const messages = Array.isArray(value?.messages) ? value.messages : [];
        for (const msg of messages) {
          if (msg?.type && msg.type !== 'text') continue;
          const from: string | undefined = msg?.from;
          const msgId: string | undefined = msg?.id;
          const bodyText: string | undefined = msg?.text?.body;
          if (!from || !msgId) continue;
          const { ok, status, body } = await rpc('ingest_offline_refill', {
            p_provider: 'whatsapp',
            p_provider_msg_id: msgId,
            p_sender_phone: '+' + from.replace(/\D/g, ''),
            p_channel: 'whatsapp',
            p_amount_usd: parseAmount(bodyText),
            p_raw: msg,
          });
          if (!ok) console.error(`ingest_offline_refill HTTP ${status}: ${JSON.stringify(body)}`);
          results.push(body);
        }
      }
    }
  } catch (e) {
    console.error('waba-webhook processing error:', e);
  }

  return json({ received: true, results }, 200);
});
