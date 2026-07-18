import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// WhatsApp Business (Cloud) API webhook — the paid-tier offline-recharge path
// (C4, PRODUCTION_PLAN.md). A user whose phone is offline sends us a WhatsApp
// message ("REFILL" or "REFILL 10"); Meta delivers it here and we turn it into
// a real, wallet-funded instant refill via `ingest_offline_refill`.
//
// This is the OFFICIAL API (not the unofficial Baileys `server_baileys.js`),
// because it is the only WhatsApp path we can bill for: the Cloud API charges
// us per conversation, and that cost is passed to the user's wallet as the
// per-channel `OFFLINE_WHATSAPP_MESSAGE_FEE_USD` (added by calculate_topup_fees).
//
// Security model: verify_jwt is disabled (Meta cannot send a Supabase JWT).
//   • GET  — Meta's subscription handshake: echo hub.challenge when
//            hub.verify_token matches WABA_VERIFY_TOKEN.
//   • POST — verified against X-Hub-Signature-256 (HMAC-SHA256 of the raw body
//            with WABA_APP_SECRET). If the secret is unset the check is skipped
//            with a warning, so the function works before creds are provisioned.
//
// The client never writes topup_executions (C3b-2 lockdown). Only this function
// (service_role) reaches ingest_offline_refill, which is service_role-only.
//
// Required function secrets (set once provisioned):
//   WABA_VERIFY_TOKEN  — arbitrary string, also entered in the Meta dashboard
//   WABA_APP_SECRET    — the Meta app secret, for payload signature checks

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

// HMAC-SHA256 hex, for X-Hub-Signature-256.
async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

// Constant-time-ish compare (length-independent guard first).
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// A body like "REFILL 10" or "top up 5.5" carries an optional USD amount; bare
// "REFILL" leaves it null so the user's configured default applies. Ignore
// absurd values rather than trusting a fat-fingered SMS.
function parseAmount(text: string | undefined): number | null {
  if (!text) return null;
  const m = text.match(/(\d+(?:\.\d{1,2})?)/);
  if (!m) return null;
  const n = Number(m[1]);
  return Number.isFinite(n) && n > 0 && n <= 500 ? n : null;
}

serve(async (req: Request) => {
  const url = new URL(req.url);

  // ── Meta subscription handshake ──────────────────────────────────────────
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

  const raw = await req.text();

  // Verify the payload signature when the app secret is configured.
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
        // Only inbound user messages trigger refills. Delivery/read status
        // callbacks (value.statuses) are acknowledged and ignored.
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
    // Never make Meta retry on our internal error — log and 200 so the event is
    // not redelivered forever. Idempotency in the RPC protects against dupes.
    console.error('waba-webhook processing error:', e);
  }

  // Meta only needs a 2xx to consider the event delivered.
  return json({ received: true, results }, 200);
});
