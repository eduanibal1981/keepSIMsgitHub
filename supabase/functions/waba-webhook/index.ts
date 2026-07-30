import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// WhatsApp Business (Cloud) API webhook — the paid-tier offline-recharge path
// (C4, PRODUCTION_PLAN.md), plus the G9 command router. A user whose phone is
// offline sends us a WhatsApp message; Meta delivers it here.
//
// G9: the body is CLASSIFIED before anything happens. Until G9 every inbound
// message went straight to `ingest_offline_refill` and queued a top-up whatever
// it said — "hi" included.
//
// D2 IP Rate Limiter applied (60/1min per IP).

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const WABA_VERIFY_TOKEN = Deno.env.get('WABA_VERIFY_TOKEN') ?? '';
const WABA_APP_SECRET = Deno.env.get('WABA_APP_SECRET') ?? '';

// G9 reply path. Unlike SMS — where the answer rides back in the TwiML response
// for free — WhatsApp needs an outbound Graph API call, which needs its own
// credentials. Neither is set today, so the classifier runs either way (which is
// what stops "BAL" queueing a $10 refill) but the reply is logged and skipped
// until these exist. Every un-sent reply is still recorded in
// `offline_command_log`, so the backlog is visible rather than lost.
const WABA_ACCESS_TOKEN = Deno.env.get('WABA_ACCESS_TOKEN') ?? '';
const WABA_PHONE_NUMBER_ID = Deno.env.get('WABA_PHONE_NUMBER_ID') ?? '';

async function sendWhatsAppText(to: string, body: string): Promise<boolean> {
  if (!WABA_ACCESS_TOKEN || !WABA_PHONE_NUMBER_ID) {
    console.warn('waba-webhook: WABA_ACCESS_TOKEN/WABA_PHONE_NUMBER_ID unset — reply not sent');
    return false;
  }
  try {
    const res = await fetch(
      `https://graph.facebook.com/v20.0/${WABA_PHONE_NUMBER_ID}/messages`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${WABA_ACCESS_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to,
          type: 'text',
          text: { body },
        }),
      },
    );
    if (!res.ok) {
      console.error(`waba send failed HTTP ${res.status}: ${await res.text()}`);
      return false;
    }
    return true;
  } catch (e) {
    console.error('waba send threw:', e);
    return false;
  }
}

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

// G9 removed the local parseAmount(): amount extraction moved into
// handle_inbound_command() so SMS and WhatsApp cannot disagree about what
// "REFILL 5" means.

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

          // G9: classify before acting. Until G9 every inbound message went
          // straight to ingest_offline_refill and queued a top-up, whatever it
          // said.
          const { ok, status, body } = await rpc('handle_inbound_command', {
            p_provider: 'whatsapp',
            p_provider_msg_id: msgId,
            p_sender_phone: '+' + from.replace(/\D/g, ''),
            p_channel: 'whatsapp',
            p_body: bodyText ?? '',
            p_raw: msg,
          });
          if (!ok) {
            console.error(`handle_inbound_command HTTP ${status}: ${JSON.stringify(body)}`);
            results.push(body);
            continue;
          }

          const reply = (body as Record<string, unknown> | null)?.['reply_text'];
          if (typeof reply === 'string' && reply.length > 0) {
            await sendWhatsAppText(from, reply);
          }
          results.push(body);
        }
      }
    }
  } catch (e) {
    console.error('waba-webhook processing error:', e);
  }

  return json({ received: true, results }, 200);
});
