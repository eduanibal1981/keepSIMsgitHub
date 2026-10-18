import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// All wallet balance mutations for the Flutter app go through this function.
// Clients have no INSERT/UPDATE grants on wallets / wallet_transactions;
// the actual mutation happens in the SECURITY DEFINER RPCs credit_wallet /
// debit_wallet_for_topup, called here with the service role. The acting user
// is always resolved from the caller's JWT — never trusted from the body.

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const jsonResponse = (body: Record<string, unknown>, status: number) =>
  new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    status,
  });

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const serviceHeaders = {
  'apikey': SERVICE_ROLE_KEY,
  'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
  'Content-Type': 'application/json',
};

async function resolveUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return null;
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { 'apikey': SERVICE_ROLE_KEY, 'Authorization': authHeader },
  });
  if (!res.ok) return null;
  const user = await res.json();
  return user?.id ?? null;
}

async function rpc(name: string, args: Record<string, unknown>): Promise<{ ok: boolean; body: any }> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: serviceHeaders,
    body: JSON.stringify(args),
  });
  const text = await res.text();
  let body: any = text;
  try { body = JSON.parse(text); } catch (_) { /* keep raw text */ }
  return { ok: res.ok, body };
}

async function fetchWallet(userId: string): Promise<any | null> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/wallets?user_id=eq.${userId}&select=*`,
    { headers: serviceHeaders },
  );
  if (!res.ok) return null;
  const rows = await res.json();
  return rows[0] ?? null;
}

async function ensureWallet(userId: string): Promise<any> {
  let wallet = await fetchWallet(userId);

  if (!wallet) {
    const rpcRes = await rpc('ensure_wallet_v2', { p_user_id: userId });
    if (rpcRes.ok && rpcRes.body) {
      wallet = rpcRes.body;
    } else {
      const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/wallets`, {
        method: 'POST',
        headers: { ...serviceHeaders, 'Prefer': 'return=representation' },
        body: JSON.stringify({ user_id: userId, balance: 0.00, currency: 'USD' }),
      });
      if (!insertRes.ok) {
        throw new Error(`Failed to create wallet: ${await insertRes.text()}`);
      }
      wallet = (await insertRes.json())[0];
    }
  }

  return wallet;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const userId = await resolveUserId(req);
    if (!userId) {
      return jsonResponse({ success: false, errorMessage: 'Not authenticated' }, 401);
    }

    const body = await req.json();
    const { action, amount, description, simLineId } = body;

    if (action === 'ensure') {
      const wallet = await ensureWallet(userId);
      return jsonResponse({ success: true, wallet }, 200);
    }

    if (action === 'summary') {
      const summaryRes = await rpc('get_wallet_summary', { p_user_id: userId });
      if (summaryRes.ok) {
        return jsonResponse({ success: true, summary: summaryRes.body }, 200);
      }
      return jsonResponse({ success: false, errorMessage: 'Failed to fetch summary' }, 500);
    }

    if (action === 'quote_refund') {
      const quoteRes = await rpc('quote_wallet_refund', { p_user_id: userId });
      return jsonResponse({ success: quoteRes.ok, quote: quoteRes.body }, quoteRes.ok ? 200 : 400);
    }

    if (action === 'request_refund') {
      if (body.expected_user_id !== undefined && body.expected_user_id !== userId) {
        return jsonResponse({ success: false, errorMessage: 'Account changed. Please retry from your current account.' }, 409);
      }
      const requestKey = body.refund_request_key;
      if (requestKey !== undefined && (typeof requestKey !== 'string' || !/^[A-Za-z0-9:_-]{8,96}$/.test(requestKey))) {
        return jsonResponse({ success: false, errorMessage: 'Invalid refund request identity' }, 400);
      }
      const reqRes = await rpc(requestKey === undefined ? 'request_wallet_refund' : 'request_wallet_refund_once', {
        p_user_id: userId,
        p_amount: Number(amount),
        p_reason: typeof description === 'string' ? description : 'Customer requested refund',
        ...(requestKey === undefined ? {} : { p_request_key: requestKey }),
      });
      return jsonResponse({ success: reqRes.ok, result: reqRes.body }, reqRes.ok ? 200 : 400);
    }

    if (action !== 'deduct') {
      return jsonResponse({ success: false, errorMessage: `Unknown action: ${action}` }, 400);
    }

    // D2 Rate limit check (wallet_deduct bucket: 20/60min per user)
    const limitRes = await rpc('consume_rate_limit', {
      p_bucket: 'wallet_deduct',
      p_key: userId,
      p_capacity: 20,
      p_refill_per_minute: 20.0 / 60.0,
    });
    if (limitRes.ok && Array.isArray(limitRes.body) && limitRes.body[0]?.allowed === false) {
      const retryAfter = limitRes.body[0]?.retry_after_seconds ?? 60;
      return new Response(
        JSON.stringify({
          success: false,
          code: 'rate_limited',
          bucket: 'wallet_deduct',
          retry_after: retryAfter,
          errorMessage: `RATE_LIMITED:wallet_deduct:${retryAfter}`,
        }),
        {
          status: 429,
          headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Retry-After': String(retryAfter) },
        },
      );
    }

    const value = Number(amount);
    if (!Number.isFinite(value) || value <= 0 || value > 10000) {
      return jsonResponse(
        { success: false, errorMessage: 'amount must be a positive number up to 10000' },
        400,
      );
    }
    const rounded = Math.round(value * 100) / 100;

    const result = await rpc('debit_wallet_for_topup', {
      p_user_id: userId,
      p_sim_line_id: typeof simLineId === 'string' && simLineId.length > 0 ? simLineId : null,
      p_amount: rounded,
      p_description: typeof description === 'string' ? description.slice(0, 500) : 'SIM top-up',
    });

    if (!result.ok) {
      const message: string = result.body?.message ?? JSON.stringify(result.body);
      const insufficient = message.includes('Insufficient wallet balance');
      return jsonResponse(
        {
          success: false,
          code: insufficient ? 'insufficient_funds' : 'rpc_error',
          errorMessage: message,
        },
        200,
      );
    }

    const wallet = await fetchWallet(userId);
    return jsonResponse(
      { success: true, transactionId: result.body, wallet },
      200,
    );
  } catch (error: any) {
    console.error('wallet_transact error:', error);
    return jsonResponse({ success: false, errorMessage: error.message }, 500);
  }
});
