import { ProviderConfigurationError, providerSecretClient, requireProviderSecret } from "../_shared/provider-secrets.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { countryCode, zenCarrier } = await req.json();

    if (!countryCode) {
      return new Response(JSON.stringify({ error: 'countryCode is required' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    const zenditApiSecret = await requireProviderSecret(
      providerSecretClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!),
      "ZENDIT_API_SECRET", ["ZENDIT_API_KEY"],
    );

    const zenditBaseUrl = 'https://api.zendit.io/v1';
    
    console.log(`Fetching offers for country: ${countryCode}`);
    const response = await fetch(`${zenditBaseUrl}/topups/offers?country=${countryCode}&_limit=100&_offset=0`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${zenditApiSecret}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error(`Zendit request failed (${response.status})`);
    }

    const data = await response.json();
    let offers = data.list || [];

    // If a specific zenCarrier is provided, filter the offers by checking if the offerId contains the carrier name
    // (Zendit offer IDs typically look like ORANGE_EG_11-1, VODAFONE_EG_008)
    // If a specific zenCarrier is provided, filter the offers by checking if the offerId or brand contains the carrier name
    // (Zendit offer IDs typically look like ORANGE_EG_11-1, VODAFONE_EG_008)
    if (zenCarrier) {
      const carrierUpper = zenCarrier.toUpperCase();
      offers = offers.filter((offer: any) => {
         const matchId = offer.offerId && offer.offerId.toUpperCase().includes(carrierUpper);
         const matchBrand = offer.brand && offer.brand.toUpperCase().includes(carrierUpper);
         return matchId || matchBrand;
      });
    }

    // Process the offers to calculate dynamic pricing
    const processedOffers = offers.map((offer: any) => {
      const costFixed = offer.cost?.fixed || offer.price?.fixed || 0;
      const divisor = offer.cost?.currencyDivisor || offer.price?.currencyDivisor || 100;
      const baseCost = costFixed / divisor;

      // Ensure we have access to all range metadata if this is a RANGE offer
      const isRange = offer.priceType === 'RANGE';
      const sendCurrencyDivisor = offer.send?.currencyDivisor || 100;
      const fxRate = offer.price?.fx || 1;
      
      const gatewayFee = isRange ? 0 : (baseCost * 0.045) + 0.30;
      const appFee = baseCost * 0.05;
      const finalPrice = baseCost + gatewayFee + appFee;

      return {
        ...offer,
        priceType: offer.priceType,
        isRange,
        sendCurrencyDivisor,
        fxRate,
        min: offer.send?.min,
        max: offer.send?.max,
        costFx: offer.cost?.fx || 1,
        baseCostUsd: baseCost,
        gatewayFeeUsd: gatewayFee,
        appFeeUsd: appFee,
        finalPriceUsd: finalPrice,
      };
    });

    return new Response(JSON.stringify({ offers: processedOffers }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error: any) {
    if (error instanceof ProviderConfigurationError) return new Response(JSON.stringify({ error: error.message, code: error.code }), { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    console.error('Error fetching Zendit offers:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
