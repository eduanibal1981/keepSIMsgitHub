import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const jsonResponse = (body: Record<string, unknown>, status: number) =>
  new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const serviceHeaders = {
  "apikey": SERVICE_ROLE_KEY,
  "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
  "Content-Type": "application/json",
};

async function resolveUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { "apikey": SERVICE_ROLE_KEY, "Authorization": authHeader },
  });
  if (!res.ok) return null;
  const user = await res.json();
  return user?.id ?? null;
}

async function fetchSystemConfig(key: string, defaultVal: string = ""): Promise<string> {
  const envVal = Deno.env.get(key);
  if (envVal) return envVal;
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/system_configs?config_key=eq.${encodeURIComponent(key)}&select=config_value`,
      { headers: serviceHeaders },
    );
    if (!res.ok) return defaultVal;
    const rows = await res.json();
    return rows[0]?.config_value ?? defaultVal;
  } catch (_) {
    return defaultVal;
  }
}

async function rpc(name: string, args: Record<string, unknown>): Promise<{ ok: boolean; body: any }> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: serviceHeaders,
    body: JSON.stringify(args),
  });
  const text = await res.text();
  let body: any = text;
  try { body = JSON.parse(text); } catch (_) { /* raw text */ }
  return { ok: res.ok, body };
}

async function resolveUserTier(userId: string): Promise<"free" | "standard" | "premium"> {
  try {
    // 1. Check profile tier
    const profRes = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?id=eq.${userId}&select=subscription_tier`,
      { headers: serviceHeaders },
    );
    if (profRes.ok) {
      const rows = await profRes.json();
      const subTier = rows[0]?.subscription_tier?.toLowerCase();
      if (subTier === "premium") return "premium";
      if (subTier === "standard") return "standard";
    }

    // 2. Check active paid SIM lines
    const nowIso = new Date().toISOString();
    const linesRes = await fetch(
      `${SUPABASE_URL}/rest/v1/sim_lines?user_id=eq.${userId}&select=plan_type,protection_tier,plan_expires_at`,
      { headers: serviceHeaders },
    );
    if (linesRes.ok) {
      const lines = await linesRes.json();
      for (const line of lines) {
        const notExpired = !line.plan_expires_at || line.plan_expires_at > nowIso;
        if (notExpired) {
          if (line.plan_type === "premium" || line.protection_tier === "premium") {
            return "premium";
          }
          if (line.plan_type === "standard" || line.protection_tier === "standard") {
            return "standard";
          }
        }
      }
    }
  } catch (e) {
    console.error("resolveUserTier error:", e);
  }
  return "free";
}

interface FeeRule {
  free_percentage: number;
  stand_percentage: number;
  prem_percentage: number;
}

async function fetchIntelCallFeeRule(): Promise<FeeRule> {
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/app_fee_rules?appfees_item=eq.intelcallfee&status=eq.published&select=free_percentage,stand_percentage,prem_percentage&order=version.desc&limit=1`,
      { headers: serviceHeaders },
    );
    if (res.ok) {
      const rows = await res.json();
      if (rows.length > 0) {
        return {
          free_percentage: Number(rows[0].free_percentage ?? 15.0),
          stand_percentage: Number(rows[0].stand_percentage ?? 7.0),
          prem_percentage: Number(rows[0].prem_percentage ?? 3.0),
        };
      }
    }
  } catch (e) {
    console.error("fetchIntelCallFeeRule error:", e);
  }
  return { free_percentage: 15.0, stand_percentage: 7.0, prem_percentage: 3.0 };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userId = await resolveUserId(req);
    if (!userId) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const action = body.action || "list";

    // ── 1. Action: List User's Active DIDs ──
    if (action === "list") {
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/virtual_did_numbers?user_id=eq.${userId}&status=eq.active&select=*&order=created_at.asc`,
        { headers: serviceHeaders },
      );
      const rows = res.ok ? await res.json() : [];
      return jsonResponse({ success: true, dids: rows }, 200);
    }

    // ── 2. Action: Search Available Phone Numbers from Telnyx ──
    if (action === "search_available_numbers") {
      const countryCode = (body.country_code || "US").toUpperCase();
      const limit = Math.min(Number(body.limit) || 12, 30);
      const phoneNumberType = body.phone_number_type || "local";

      const apiKey = await fetchSystemConfig("TELNYX_API_KEY");
      if (!apiKey) {
        return jsonResponse({ error: "Telnyx telephony integration is not configured." }, 500);
      }

      const userTier = await resolveUserTier(userId);
      const feeRule = await fetchIntelCallFeeRule();

      const feePercent = userTier === "premium"
        ? feeRule.prem_percentage
        : userTier === "standard"
          ? feeRule.stand_percentage
          : feeRule.free_percentage;

      const query = new URLSearchParams({
        "filter[country_code]": countryCode,
        "filter[limit]": limit.toString(),
        "filter[phone_number_type]": phoneNumberType,
        "filter[features]": "voice",
      });

      if (body.area_code) {
        query.set("filter[national_destination_code]", String(body.area_code));
      }

      const telnyxRes = await fetch(`https://api.telnyx.com/v2/available_phone_numbers?${query.toString()}`, {
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
      });

      if (!telnyxRes.ok) {
        const errText = await telnyxRes.text();
        console.error("Telnyx available_phone_numbers failed:", errText);
        return jsonResponse({
          success: false,
          error: "Failed to search available numbers from carrier network.",
          details: errText,
        }, 502);
      }

      const telnyxData = await telnyxRes.json();
      const rawNumbers = telnyxData?.data || [];

      const numbers = rawNumbers.map((item: any) => {
        const wholesaleMonthly = parseFloat(item.cost_information?.monthly_cost || "1.00");
        const wholesaleUpfront = parseFloat(item.cost_information?.upfront_cost || "0.00");
        const appFeeUsd = Math.round(wholesaleMonthly * (feePercent / 100.0) * 100) / 100;
        const totalMonthlyUsd = Math.round((wholesaleMonthly + appFeeUsd) * 100) / 100;

        const regionInfo = item.region_information || [];
        const stateObj = regionInfo.find((r: any) => r.region_type === "state");
        const locObj = regionInfo.find((r: any) => r.region_type === "location" || r.region_type === "rate_center");

        return {
          phone_number: item.phone_number,
          formatted_number: item.vanity_format || item.phone_number,
          country_code: countryCode,
          state: stateObj?.region_name || null,
          city: locObj?.region_name || null,
          phone_number_type: item.phone_number_type || "local",
          features: (item.features || []).map((f: any) => f.name),
          wholesale_monthly_usd: wholesaleMonthly,
          wholesale_upfront_usd: wholesaleUpfront,
          app_fee_percent: feePercent,
          app_fee_usd: appFeeUsd,
          total_monthly_usd: totalMonthlyUsd,
          user_tier: userTier,
          currency: "USD",
        };
      });

      return jsonResponse({
        success: true,
        country_code: countryCode,
        user_tier: userTier,
        fee_percent: feePercent,
        numbers,
        count: numbers.length,
      }, 200);
    }

    // ── 3. Action: Purchase & Provision Virtual Number ──
    if (action === "purchase_number") {
      const phoneNumber = body.phone_number;
      const countryCode = (body.country_code || "US").toUpperCase();
      const countryName = body.country_name || (countryCode === "US" ? "United States" : countryCode);

      if (!phoneNumber) {
        return jsonResponse({ error: "Missing required parameter 'phone_number'" }, 400);
      }

      const apiKey = await fetchSystemConfig("TELNYX_API_KEY");
      const callControlAppId = await fetchSystemConfig("TELNYX_CALL_CONTROL_APP_ID", "3036680705380714233");

      if (!apiKey) {
        return jsonResponse({ error: "Telnyx telephony integration is not configured." }, 500);
      }

      // Check if number is already provisioned
      const existingCheck = await fetch(
        `${SUPABASE_URL}/rest/v1/virtual_did_numbers?phone_number=eq.${encodeURIComponent(phoneNumber)}&status=eq.active&select=id`,
        { headers: serviceHeaders },
      );
      if (existingCheck.ok) {
        const existing = await existingCheck.json();
        if (existing.length > 0) {
          return jsonResponse({ error: "This virtual number is already provisioned." }, 400);
        }
      }

      // 1. Calculate price with intelcallfee
      const userTier = await resolveUserTier(userId);
      const feeRule = await fetchIntelCallFeeRule();
      const feePercent = userTier === "premium"
        ? feeRule.prem_percentage
        : userTier === "standard"
          ? feeRule.stand_percentage
          : feeRule.free_percentage;

      const wholesaleMonthly = 1.00; // Base wholesale Telnyx DID cost
      const appFeeUsd = Math.round(wholesaleMonthly * (feePercent / 100.0) * 100) / 100;
      const totalMonthlyUsd = Math.round((wholesaleMonthly + appFeeUsd) * 100) / 100;

      // 2. Check Wallet Balance
      const walletRes = await fetch(
        `${SUPABASE_URL}/rest/v1/wallets?user_id=eq.${userId}&select=id,balance`,
        { headers: serviceHeaders },
      );
      if (!walletRes.ok) {
        return jsonResponse({ error: "Could not retrieve user wallet." }, 500);
      }
      const wallets = await walletRes.json();
      const userWallet = wallets[0];
      if (!userWallet) {
        return jsonResponse({ error: "User wallet not found." }, 404);
      }

      const currentBalance = parseFloat(userWallet.balance || "0");
      if (currentBalance < totalMonthlyUsd) {
        return jsonResponse({
          success: false,
          code: "insufficient_funds",
          required_usd: totalMonthlyUsd,
          current_balance_usd: currentBalance,
          message: `Insufficient wallet balance. You have $${currentBalance.toFixed(2)} and need $${totalMonthlyUsd.toFixed(2)}.`,
        }, 200);
      }

      // 3. Place Order with Telnyx
      console.log(`[manage-dids] Ordering Telnyx number ${phoneNumber} for user ${userId}...`);
      const orderPayload: Record<string, unknown> = {
        phone_numbers: [{ phone_number: phoneNumber }],
      };
      if (callControlAppId) {
        orderPayload.connection_id = callControlAppId;
      }

      const orderRes = await fetch("https://api.telnyx.com/v2/number_orders", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(orderPayload),
      });

      if (!orderRes.ok) {
        const orderErr = await orderRes.text();
        console.error("Telnyx number order error:", orderErr);
        return jsonResponse({
          success: false,
          error: "Carrier order could not be completed. The number may have been reserved by another customer.",
          details: orderErr,
        }, 400);
      }

      const orderData = await orderRes.json();
      console.log(`[manage-dids] Telnyx order placed successfully:`, orderData?.data?.id);

      // 4. Assign Call Control Connection on the ordered number if needed
      try {
        if (callControlAppId) {
          // Look up phone number id on Telnyx to ensure connection is bound
          const findNumRes = await fetch(`https://api.telnyx.com/v2/phone_numbers?filter[phone_number]=${encodeURIComponent(phoneNumber)}`, {
            headers: { "Authorization": `Bearer ${apiKey}` },
          });
          if (findNumRes.ok) {
            const foundData = await findNumRes.json();
            const numId = foundData?.data?.[0]?.id;
            if (numId) {
              await fetch(`https://api.telnyx.com/v2/phone_numbers/${numId}`, {
                method: "PATCH",
                headers: {
                  "Authorization": `Bearer ${apiKey}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({ connection_id: callControlAppId }),
              });
            }
          }
        }
      } catch (bindErr) {
        console.warn("Could not immediately bind connection_id:", bindErr);
      }

      // 5. Atomically Debit Wallet
      const debitRes = await rpc("debit_wallet_for_topup", {
        p_user_id: userId,
        p_sim_line_id: null,
        p_amount: totalMonthlyUsd,
        p_description: `KeepSIMs Virtual Number Purchase (${phoneNumber})`,
        p_reference_id: `did_${phoneNumber.replace(/\+/g, "")}_${Date.now()}`,
        p_txn_type: "did_purchase_debit",
      });

      if (!debitRes.ok) {
        console.error("Wallet debit failed after Telnyx order:", debitRes.body);
      }

      // 6. Insert into virtual_did_numbers
      const insertPayload = {
        user_id: userId,
        phone_number: phoneNumber,
        country_code: countryCode,
        country_name: countryName,
        provider: "telnyx",
        status: "active",
        monthly_fee_usd: totalMonthlyUsd,
        forward_mode: "app",
        auto_renew: true,
        renews_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/virtual_did_numbers`, {
        method: "POST",
        headers: { ...serviceHeaders, "Prefer": "return=representation" },
        body: JSON.stringify(insertPayload),
      });

      if (!insertRes.ok) {
        const insertErr = await insertRes.text();
        console.error("Failed to insert virtual_did_number row:", insertErr);
        return jsonResponse({
          success: false,
          error: "Number provisioned with carrier, but record creation failed. Contact support.",
        }, 500);
      }

      const insertedDid = (await insertRes.json())[0];

      return jsonResponse({
        success: true,
        did: insertedDid,
        fee_breakdown: {
          wholesale_usd: wholesaleMonthly,
          app_fee_percent: feePercent,
          app_fee_usd: appFeeUsd,
          total_monthly_usd: totalMonthlyUsd,
          tier: userTier,
        },
      }, 200);
    }

    // ── 4. Action: Update Forwarding Mode ──
    if (action === "update_forwarding") {
      const didId = body.did_id;
      const forwardMode = body.forward_mode;
      const forwardDestination = body.forward_destination;

      if (!didId || !forwardMode) {
        return jsonResponse({ error: "Missing did_id or forward_mode" }, 400);
      }

      const validModes = ["app", "pstn", "voicemail", "sim_roaming"];
      if (!validModes.includes(forwardMode)) {
        return jsonResponse({ error: `Invalid forward_mode '${forwardMode}'` }, 400);
      }

      const updatePayload: Record<string, unknown> = {
        forward_mode: forwardMode,
        forward_destination: (forwardMode === "pstn" || forwardMode === "sim_roaming") ? (forwardDestination || null) : null,
        updated_at: new Date().toISOString(),
      };

      const updateRes = await fetch(
        `${SUPABASE_URL}/rest/v1/virtual_did_numbers?id=eq.${encodeURIComponent(didId)}&user_id=eq.${userId}&status=eq.active`,
        {
          method: "PATCH",
          headers: { ...serviceHeaders, "Prefer": "return=representation" },
          body: JSON.stringify(updatePayload),
        }
      );

      if (!updateRes.ok) {
        const errText = await updateRes.text();
        return jsonResponse({ error: `Failed to update forwarding: ${errText}` }, 500);
      }

      const updatedRows = await updateRes.json();
      return jsonResponse({ success: true, did: updatedRows[0] }, 200);
    }

    // ── 5. Action: Get Forwarding Codes with Real Carrier MMI Format ──
    if (action === "get_forwarding_codes") {
      const didId = body.did_id;
      const carrierId = body.carrier_id;

      if (!didId) {
        return jsonResponse({ error: "Missing did_id" }, 400);
      }

      const didRes = await fetch(
        `${SUPABASE_URL}/rest/v1/virtual_did_numbers?id=eq.${encodeURIComponent(didId)}&user_id=eq.${userId}&status=eq.active&select=phone_number`,
        { headers: serviceHeaders }
      );
      const didRows = didRes.ok ? await didRes.json() : [];
      if (didRows.length === 0) {
        return jsonResponse({ error: "DID number not found" }, 404);
      }

      const didNumber = didRows[0].phone_number;

      // Look up carrier rule if carrierId specified
      let cfuFormat = "**21*{number}#";
      let cfuCancel = "##21#";
      let specialNotes = null;

      if (carrierId) {
        const ruleRes = await fetch(
          `${SUPABASE_URL}/rest/v1/carrier_call_forwarding_rules?carrier_id=eq.${encodeURIComponent(carrierId)}&select=*`,
          { headers: serviceHeaders },
        );
        if (ruleRes.ok) {
          const rules = await ruleRes.json();
          if (rules.length > 0) {
            cfuFormat = rules[0].cfu_format || cfuFormat;
            cfuCancel = rules[0].cfu_cancel || cfuCancel;
            specialNotes = rules[0].special_notes;
          }
        }
      }

      const formattedCode = cfuFormat.replace("{number}", didNumber);

      return jsonResponse({
        success: true,
        did_number: didNumber,
        formatted_code: formattedCode,
        cancel_code: cfuCancel,
        special_notes: specialNotes,
        instructions: {
          unconditional_forward: {
            title: "Forward All Calls (Recommended before boarding)",
            code: formattedCode,
            cancel_code: cfuCancel,
            description: "All incoming calls to your home SIM will route to KeepSIMs. Your physical SIM won't ring.",
          },
        },
      }, 200);
    }

    return jsonResponse({ error: `Unknown action '${action}'` }, 400);
  } catch (err: any) {
    console.error("manage-dids unhandled error:", err);
    return jsonResponse({ error: err?.message || String(err) }, 500);
  }
});
