import { SecondNumbers } from "../_shared/second-number.ts";
import { EndpointError, requireAdmin } from "../_shared/endpoint-auth.ts";
import { ProviderConfigurationError } from "../_shared/provider-secrets.ts";
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
  return user?.app_metadata?.is_suspended === true ? null : user?.id ?? null;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") return jsonResponse({error:"Method not allowed"},405);

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
        `${SUPABASE_URL}/rest/v1/virtual_did_numbers?user_id=eq.${userId}&status=eq.active&select=id,phone_number,country_code,country_name,status,monthly_fee_usd,forward_mode,forward_destination,auto_renew,renews_at,created_at&order=created_at.asc`,
        { headers: serviceHeaders },
      );
      const rows = res.ok ? await res.json() : [];
      return jsonResponse({ success: true, dids: rows }, 200);
    }

    const second = new SecondNumbers(SUPABASE_URL, SERVICE_ROLE_KEY);
    if (action === "validate_pilot") {
      await requireAdmin(req,SUPABASE_URL,SERVICE_ROLE_KEY);
      return jsonResponse(await second.validatePilot(),200);
    }
    if (action === "get_countries") return jsonResponse({success: true, countries: await second.policies(userId)}, 200);
    if (action === "search_available_numbers") return jsonResponse(await second.search(userId, body), 200);
    if (action === "purchase_number") return jsonResponse(await second.purchase(userId, body), 200);
    if (action === "order_status") return jsonResponse(await second.order(userId, body.order_id), 200);

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
      return jsonResponse({ success: true, did: updatedRows[0] ? {id:updatedRows[0].id,forward_mode:updatedRows[0].forward_mode,forward_destination:updatedRows[0].forward_destination} : null }, 200);
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
    if (err instanceof EndpointError) return jsonResponse({error:err.message},err.status);
    if (err instanceof ProviderConfigurationError) return jsonResponse({ error: err.message, code: err.code }, 503);
    return jsonResponse({ error: "Number management is temporarily unavailable." }, 503);
  }
});
