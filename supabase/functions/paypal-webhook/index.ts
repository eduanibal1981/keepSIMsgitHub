import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// PayPal webhook receiver — the ONLY path that credits wallet deposits.
// The client never credits itself: it creates/captures the PayPal order and
// then waits for this webhook to land the money (B3, PRODUCTION_PLAN.md).
//
// Security model: verify_jwt is disabled (PayPal cannot send a Supabase JWT);
// instead every event is verified against PayPal's
// /v1/notifications/verify-webhook-signature API using the transmission
// headers, our webhook id, and the exact raw body. Anything that fails
// verification is rejected with 400.
//
// Required function secrets:
//   PAYPAL_CLIENT_ID / PAYPAL_CLIENT_SECRET  — REST app credentials
//   PAYPAL_WEBHOOK_ID                        — id of this webhook registration
//   PAYPAL_API_BASE                          — optional, defaults to sandbox

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PAYPAL_CLIENT_ID = Deno.env.get('PAYPAL_CLIENT_ID') ?? '';
const PAYPAL_CLIENT_SECRET = Deno.env.get('PAYPAL_CLIENT_SECRET') ?? '';
const PAYPAL_WEBHOOK_ID = Deno.env.get('PAYPAL_WEBHOOK_ID') ?? '';
const PAYPAL_API_BASE = Deno.env.get('PAYPAL_API_BASE') ?? 'https://api-m.sandbox.paypal.com';

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

async function paypalAccessToken(): Promise<string> {
  const res = await fetch(`${PAYPAL_API_BASE}/v1/oauth2/token`, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${btoa(`${PAYPAL_CLIENT_ID}:${PAYPAL_CLIENT_SECRET}`)}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });
  if (!res.ok) {
    throw new Error(`PayPal OAuth failed (${res.status}): ${await res.text()}`);
  }
  return (await res.json()).access_token;
}

async function verifySignature(req: Request, rawBody: string): Promise<boolean> {
  const h = req.headers;
  const payload = {
    transmission_id: h.get('paypal-transmission-id'),
    transmission_time: h.get('paypal-transmission-time'),
    cert_url: h.get('paypal-cert-url'),
    auth_algo: h.get('paypal-auth-algo'),
    transmission_sig: h.get('paypal-transmission-sig'),
    webhook_id: PAYPAL_WEBHOOK_ID,
    webhook_event: JSON.parse(rawBody),
  };
  if (!payload.transmission_id || !payload.transmission_sig || !payload.cert_url) {
    return false;
  }
  const token = await paypalAccessToken();
  const res = await fetch(`${PAYPAL_API_BASE}/v1/notifications/verify-webhook-signature`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    console.error(`verify-webhook-signature HTTP ${res.status}: ${await res.text()}`);
    return false;
  }
  const { verification_status } = await res.json();
  return verification_status === 'SUCCESS';
}

async function systemAlert(kind: string, message: string, details: Record<string, unknown>) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/system_alerts`, {
    method: 'POST',
    headers: serviceHeaders,
    body: JSON.stringify({ kind, message, details }),
  });
  if (!res.ok) console.error(`system_alerts insert failed: ${await res.text()}`);
}

async function rpc(name: string, args: Record<string, unknown>): Promise<{ ok: boolean; status: number; body: any }> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: serviceHeaders,
    body: JSON.stringify(args),
  });
  const text = await res.text();
  let body: any = text;
  try { body = JSON.parse(text); } catch (_) { /* raw text */ }
  return { ok: res.ok, status: res.status, body };
}

// custom_id set at order creation: either the bare user uuid, or JSON
// {"u": "<uuid>", "k": "<kind>", "l": "<sim_line_id>"} for future flows (direct-pay refill,
// subscriptions).
function parseCustomId(customId: string | undefined): { userId: string | null; kind: string; simLineId: string | null } {
  if (!customId) return { userId: null, kind: 'deposit', simLineId: null };
  try {
    const parsed = JSON.parse(customId);
    if (parsed && typeof parsed.u === 'string') {
      return {
        userId: parsed.u,
        kind: typeof parsed.k === 'string' ? parsed.k : 'deposit',
        simLineId: typeof parsed.l === 'string' ? parsed.l : null,
      };
    }
  } catch (_) { /* not JSON — treat as bare uuid */ }
  const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRe.test(customId) ? { userId: customId, kind: 'deposit', simLineId: null } : { userId: null, kind: 'deposit', simLineId: null };
}

async function handleCaptureCompleted(event: any): Promise<Response> {
  const capture = event.resource ?? {};
  const captureId: string | undefined = capture.id;
  const orderId: string | undefined = capture.supplementary_data?.related_ids?.order_id;
  const currency: string | undefined = capture.amount?.currency_code;
  const gross = Number(capture.amount?.value);
  const breakdown = capture.seller_receivable_breakdown ?? {};
  const fee = Number(breakdown.paypal_fee?.value ?? 0);
  const net = Number(breakdown.net_amount?.value ?? gross);
  const { userId, kind, simLineId } = parseCustomId(capture.custom_id);

  if (!captureId || !Number.isFinite(gross) || gross <= 0) {
    await systemAlert('paypal_webhook_malformed',
      `PAYMENT.CAPTURE.COMPLETED with missing capture id or bad amount (event ${event.id}).`,
      { event_id: event.id, capture_id: captureId ?? null, amount: capture.amount ?? null });
    return json({ received: true, credited: false, reason: 'malformed' }, 200);
  }

  if (currency !== 'USD') {
    await systemAlert('paypal_currency_mismatch',
      `PayPal capture ${captureId} in ${currency}, expected USD. Not credited.`,
      { capture_id: captureId, order_id: orderId ?? null, amount: capture.amount });
    return json({ received: true, credited: false, reason: 'currency_mismatch' }, 200);
  }

  if (!userId) {
    await systemAlert('paypal_unattributed_payment',
      `PayPal capture ${captureId} ($${gross}) has no usable custom_id — cannot credit a wallet.`,
      { capture_id: captureId, order_id: orderId ?? null, custom_id: capture.custom_id ?? null, gross });
    return json({ received: true, credited: false, reason: 'no_custom_id' }, 200);
  }

  // Plan charges (kind 'plan') are payments TO KeepSIMs, not wallet deposits.
  // Before C3c every plan charge was tagged 'deposit', so the webhook credited
  // the full charge back into the payer's wallet — paid plans were free.
  if (kind === 'plan') {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/plan_payments`, {
      method: 'POST',
      headers: { ...serviceHeaders, 'Prefer': 'return=minimal' },
      body: JSON.stringify({
        user_id: userId,
        sim_line_id: simLineId ?? null,
        capture_id: captureId,
        order_id: orderId ?? null,
        kind,
        gross_usd: gross,
        paypal_fee_usd: fee,
        net_usd: net,
        metadata: {
          event_id: event.id,
          event_time: event.create_time ?? null,
          currency,
        },
      }),
    });

    if (res.ok) {
      console.log(`Recorded plan payment $${gross} from ${userId} (capture ${captureId})`);
      return json({ received: true, recorded: true }, 200);
    }

    const body = await res.text();
    if (res.status === 409 || body.includes('duplicate key')) {
      console.log(`Plan payment ${captureId} already recorded — webhook retry, ignoring.`);
      return json({ received: true, recorded: false, reason: 'already_recorded' }, 200);
    }

    // Transient — 500 so PayPal retries rather than losing the record.
    console.error(`plan_payments insert failed for ${captureId}: ${body}`);
    return json({ received: true, recorded: false, error: body }, 500);
  }

  if (kind !== 'deposit') {
    // Future flows (direct-pay refill) route here later; alert so nothing
    // silently disappears until they are built.
    await systemAlert('paypal_unhandled_kind',
      `PayPal capture ${captureId} carries kind '${kind}', which has no handler yet. Not credited.`,
      { capture_id: captureId, order_id: orderId ?? null, kind, user_id: userId, gross });
    return json({ received: true, credited: false, reason: 'unhandled_kind' }, 200);
  }

  const result = await rpc('credit_wallet_for_deposit', {
    p_user_id: userId,
    p_amount: gross,
    p_description: `PayPal deposit (order ${orderId ?? 'n/a'})`,
    p_reference_id: `paypal_${captureId}`,
    p_metadata: {
      method: 'paypal',
      paypal_capture_id: captureId,
      paypal_order_id: orderId ?? null,
      gross: gross,
      paypal_fee: fee,
      net: net,
      currency: currency,
      payer_email: event.resource?.payee?.email_address ?? null,
      event_id: event.id,
      event_time: event.create_time ?? null,
    },
  });

  if (result.ok) {
    console.log(`Credited $${gross} to ${userId} for capture ${captureId} (txn ${result.body})`);
    return json({ received: true, credited: true }, 200);
  }

  const message: string = result.body?.message ?? JSON.stringify(result.body);
  if (result.body?.code === '23505' || message.includes('duplicate key')) {
    console.log(`Capture ${captureId} already credited — webhook retry, ignoring.`);
    return json({ received: true, credited: false, reason: 'already_credited' }, 200);
  }

  // 'Wallet not found' is permanent — alert and ack so PayPal stops retrying.
  if (message.includes('Wallet not found')) {
    await systemAlert('paypal_wallet_missing',
      `PayPal capture ${captureId} ($${gross}) for user ${userId} but no wallet exists.`,
      { capture_id: captureId, user_id: userId, gross });
    return json({ received: true, credited: false, reason: 'wallet_missing' }, 200);
  }

  // Transient (DB down etc.) — 500 so PayPal retries the delivery.
  console.error(`credit_wallet_for_deposit failed for ${captureId}: ${message}`);
  return json({ received: true, credited: false, error: message }, 500);
}

async function handleFailureEvent(event: any): Promise<Response> {
  const r = event.resource ?? {};
  await systemAlert('paypal_payment_problem',
    `PayPal event ${event.event_type} for ${r.id ?? 'unknown resource'} — review in the PayPal dashboard.`,
    {
      event_id: event.id,
      event_type: event.event_type,
      resource_id: r.id ?? null,
      amount: r.amount ?? null,
      status: r.status ?? null,
      custom_id: r.custom_id ?? null,
      summary: event.summary ?? null,
    });
  return json({ received: true }, 200);
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  try {
    if (!PAYPAL_CLIENT_ID || !PAYPAL_CLIENT_SECRET || !PAYPAL_WEBHOOK_ID) {
      console.error('paypal-webhook secrets not configured (PAYPAL_CLIENT_ID/SECRET/WEBHOOK_ID)');
      return json({ error: 'webhook not configured' }, 500);
    }

    const rawBody = await req.text();

    if (!(await verifySignature(req, rawBody))) {
      console.error('Webhook signature verification FAILED');
      return json({ error: 'signature verification failed' }, 400);
    }

    const event = JSON.parse(rawBody);
    const type: string = event.event_type ?? '';
    console.log(`Verified PayPal event ${event.id}: ${type}`);

    if (type === 'PAYMENT.CAPTURE.COMPLETED') {
      return await handleCaptureCompleted(event);
    }

    if ([
      'PAYMENT.CAPTURE.REFUNDED',
      'PAYMENT.CAPTURE.REVERSED',
      'PAYMENT.CAPTURE.DENIED',
      'PAYMENT.CAPTURE.DECLINED',
      'CHECKOUT.PAYMENT-APPROVAL.REVERSED',
    ].includes(type)) {
      return await handleFailureEvent(event);
    }

    // All other events (webhook is registered for "All Events"): acknowledge.
    return json({ received: true, ignored: type }, 200);
  } catch (error: any) {
    console.error('paypal-webhook error:', error);
    return json({ error: error.message }, 500);
  }
});
