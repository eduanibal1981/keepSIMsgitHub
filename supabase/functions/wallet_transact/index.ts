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

/// Get-or-create the wallet, preserving the app's existing welcome-credit
/// behavior ($43.20 welcome + $2.00 referral = $45.20 starting balance).
async function ensureWallet(userId: string): Promise<any> {
  let wallet = await fetchWallet(userId);

  if (!wallet) {
    const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/wallets`, {
      method: 'POST',
      headers: { ...serviceHeaders, 'Prefer': 'return=representation' },
      body: JSON.stringify({ user_id: userId, balance: 45.20, currency: 'USD' }),
    });
    if (!insertRes.ok) {
      throw new Error(`Failed to create wallet: ${await insertRes.text()}`);
    }
    wallet = (await insertRes.json())[0];
  }

  // Seed the welcome ledger if it is empty, matching the wallet balance.
  const txRes = await fetch(
    `${SUPABASE_URL}/rest/v1/wallet_transactions?user_id=eq.${userId}&select=id&limit=1`,
    { headers: serviceHeaders },
  );
  const existing = txRes.ok ? await txRes.json() : [];
  if (existing.length === 0) {
    await fetch(`${SUPABASE_URL}/rest/v1/wallet_transactions`, {
      method: 'POST',
      headers: serviceHeaders,
      body: JSON.stringify([
        {
          user_id: userId, wallet_id: wallet.id, amount: 43.20,
          balance_before: 0.00, balance_after: 43.20,
          type: 'deposit', status: 'completed',
          description: 'Welcome Credit', reference_id: 'welcome_bonus',
        },
        {
          user_id: userId, wallet_id: wallet.id, amount: 2.00,
          balance_before: 43.20, balance_after: 45.20,
          type: 'referral_credit', status: 'completed',
          description: 'Referral Reward', reference_id: 'referral_bonus',
        },
      ]),
    });
    if ((wallet.balance ?? 0) !== 45.20) {
      const alignRes = await fetch(`${SUPABASE_URL}/rest/v1/wallets?id=eq.${wallet.id}`, {
        method: 'PATCH',
        headers: { ...serviceHeaders, 'Prefer': 'return=representation' },
        body: JSON.stringify({ balance: 45.20 }),
      });
      if (alignRes.ok) wallet = (await alignRes.json())[0] ?? wallet;
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

    const { action, amount, description, simLineId } = await req.json();

    if (action === 'ensure') {
      const wallet = await ensureWallet(userId);
      return jsonResponse({ success: true, wallet }, 200);
    }

    // 'deposit' was removed in B3: the client chose its own credit amount,
    // which is indistinguishable from minting money. Deposits are credited
    // exclusively by the paypal-webhook function after PayPal confirms a
    // capture.
    if (action !== 'deduct') {
      return jsonResponse({ success: false, errorMessage: `Unknown action: ${action}` }, 400);
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
