import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const jsonResponse = (body: Record<string, unknown>, status: number) =>
  new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    status,
  });

// verify_jwt accepts the public anon key, so require a real user session:
// this endpoint spends money.
async function isAuthenticatedUser(req: Request): Promise<boolean> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return false;
  const res = await fetch(`${Deno.env.get('SUPABASE_URL')}/auth/v1/user`, {
    headers: {
      'apikey': Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      'Authorization': authHeader,
    },
  });
  if (!res.ok) return false;
  const user = await res.json();
  return typeof user?.id === 'string';
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (!(await isAuthenticatedUser(req))) {
      return jsonResponse(
        { success: false, transactionId: '', errorMessage: 'Not authenticated' },
        401,
      );
    }

    const { phoneNumber, countryCode, amount } = await req.json();

    if (!phoneNumber || !countryCode || typeof amount !== 'number' || amount <= 0) {
      return jsonResponse(
        { success: false, transactionId: '', errorMessage: 'phoneNumber, countryCode and a positive amount are required' },
        400,
      );
    }

    const zenditApiSecret = Deno.env.get('ZENDIT_API_SECRET');
    if (!zenditApiSecret) {
      throw new Error('ZENDIT_API_SECRET is not set');
    }

    const zenditBaseUrl = 'https://api.zendit.io/v1';
    const zenditHeaders = {
      'Authorization': `Bearer ${zenditApiSecret}`,
      'Content-Type': 'application/json',
    };

    // 1. Fetch offers for the country
    const offerResponse = await fetch(
      `${zenditBaseUrl}/topups/offers?country=${encodeURIComponent(countryCode)}&_limit=100&_offset=0`,
      { headers: zenditHeaders },
    );

    if (!offerResponse.ok) {
      const errorText = await offerResponse.text();
      return jsonResponse(
        { success: false, transactionId: '', errorMessage: `Failed to fetch offers: ${errorText}` },
        200,
      );
    }

    const offerData = await offerResponse.json();
    const offers: any[] = offerData.list || [];

    if (offers.length === 0) {
      return jsonResponse(
        { success: false, transactionId: '', errorMessage: `No top-up offers available for country: ${countryCode}` },
        200,
      );
    }

    // 2. Find the offer whose USD price is closest to the requested amount
    let bestOffer: any = null;
    let minDiff = Infinity;
    for (const offer of offers) {
      const price = offer.price;
      if (!price) continue;
      const offerUsd = (price.fixed ?? 0) / (price.currencyDivisor ?? 100);
      const diff = Math.abs(offerUsd - amount);
      if (diff < minDiff) {
        minDiff = diff;
        bestOffer = offer;
      }
    }

    if (!bestOffer) {
      return jsonResponse(
        { success: false, transactionId: '', errorMessage: `No matching offer found for amount: $${amount.toFixed(2)}` },
        200,
      );
    }

    const transactionId = `z_srv_${Date.now()}`;
    const formattedPhone = String(phoneNumber).startsWith('+') ? String(phoneNumber) : `+${phoneNumber}`;

    const send = bestOffer.send ?? {};
    const sendAmount = (send.fixed ?? 0) / (send.currencyDivisor ?? 100);
    const localBenefit = `${sendAmount.toFixed(2)} ${send.currency ?? ''}`;

    const price = bestOffer.price ?? {};
    const actualUsdCost = (price.fixed ?? 0) / (price.currencyDivisor ?? 100);

    // 3. Execute the purchase
    const purchaseResponse = await fetch(`${zenditBaseUrl}/topups/purchases`, {
      method: 'POST',
      headers: zenditHeaders,
      body: JSON.stringify({
        transactionId,
        offerId: bestOffer.offerId,
        recipientPhoneNumber: formattedPhone,
      }),
    });

    if (!purchaseResponse.ok) {
      const errorText = await purchaseResponse.text();
      return jsonResponse(
        { success: false, transactionId, errorMessage: `Purchase API Error: ${purchaseResponse.status} - ${errorText}` },
        200,
      );
    }

    let purchaseData = await purchaseResponse.json();
    let currentStatus: string = purchaseData.status ?? 'PENDING';

    // 4. Poll up to 5 times (1s apart) for a terminal status
    const nonTerminal = ['ACCEPTED', 'PENDING', 'AUTHORIZED', 'IN_PROGRESS'];
    for (let poll = 0; nonTerminal.includes(currentStatus) && poll < 5; poll++) {
      await new Promise((resolve) => setTimeout(resolve, 1000));
      try {
        const checkResponse = await fetch(`${zenditBaseUrl}/topups/purchases/${transactionId}`, {
          headers: zenditHeaders,
        });
        if (checkResponse.ok) {
          purchaseData = await checkResponse.json();
          currentStatus = purchaseData.status ?? currentStatus;
        }
      } catch (_) {
        // Ignore transient network errors while polling
      }
    }

    if (currentStatus === 'FAILED' || currentStatus === 'DECLINED') {
      return jsonResponse(
        {
          success: false,
          transactionId: purchaseData.transactionId ?? transactionId,
          errorMessage: purchaseData.error?.message ?? `Transaction failed with status: ${currentStatus}`,
        },
        200,
      );
    }

    return jsonResponse(
      {
        success: true,
        transactionId: purchaseData.transactionId ?? transactionId,
        amountToppedUp: actualUsdCost,
        localBenefit,
      },
      200,
    );
  } catch (error: any) {
    console.error('Error executing Zendit recharge:', error);
    return jsonResponse(
      { success: false, transactionId: '', errorMessage: error.message },
      500,
    );
  }
});
