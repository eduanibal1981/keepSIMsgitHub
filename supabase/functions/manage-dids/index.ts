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

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userId = await resolveUserId(req);
    if (!userId) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const { action = "list", did_id, forward_mode, forward_destination } = await req.json().catch(() => ({ action: "list" }));

    if (action === "list") {
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/virtual_did_numbers?user_id=eq.${userId}&status=eq.active&select=*&order=created_at.asc`,
        { headers: serviceHeaders }
      );
      const rows = res.ok ? await res.json() : [];
      return jsonResponse({ success: true, dids: rows }, 200);
    }

    if (action === "update_forwarding") {
      if (!did_id || !forward_mode) {
        return jsonResponse({ error: "Missing did_id or forward_mode" }, 400);
      }

      const validModes = ["app", "pstn", "voicemail", "sim_roaming"];
      if (!validModes.includes(forward_mode)) {
        return jsonResponse({ error: `Invalid forward_mode '${forward_mode}'` }, 400);
      }

      const updatePayload: Record<string, unknown> = {
        forward_mode,
        forward_destination: (forward_mode === "pstn" || forward_mode === "sim_roaming") ? (forward_destination || null) : null,
        updated_at: new Date().toISOString(),
      };

      const updateRes = await fetch(
        `${SUPABASE_URL}/rest/v1/virtual_did_numbers?id=eq.${encodeURIComponent(did_id)}&user_id=eq.${userId}&status=eq.active`,
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

    if (action === "get_forwarding_codes") {
      if (!did_id) {
        return jsonResponse({ error: "Missing did_id" }, 400);
      }

      const didRes = await fetch(
        `${SUPABASE_URL}/rest/v1/virtual_did_numbers?id=eq.${encodeURIComponent(did_id)}&user_id=eq.${userId}&status=eq.active&select=phone_number`,
        { headers: serviceHeaders }
      );
      const didRows = didRes.ok ? await didRes.json() : [];
      if (didRows.length === 0) {
        return jsonResponse({ error: "DID number not found" }, 404);
      }

      const didNumber = didRows[0].phone_number;
      return jsonResponse({
        success: true,
        did_number: didNumber,
        instructions: {
          unconditional_forward: {
            title: "Forward All Calls (Recommended before boarding)",
            code: `**21*${didNumber}#`,
            description: "All incoming calls to your home SIM will ring inside KeepSIMs. Your physical SIM won't ring.",
          },
          unanswered_forward: {
            title: "Forward When Unanswered",
            code: `**61*${didNumber}**20#`,
            description: "If you don't answer within 20 seconds, the call automatically routes to KeepSIMs.",
          },
          unreachable_forward: {
            title: "Forward When Out of Coverage / Airplane Mode",
            code: `**62*${didNumber}#`,
            description: "Routes incoming calls to KeepSIMs whenever your phone is in Airplane Mode or off.",
          },
          cancel_forward: {
            title: "Deactivate Forwarding (Upon Returning Home)",
            code: "##21#",
            description: "Cancels unconditional forwarding so your home SIM receives normal calls again.",
          },
        },
      }, 200);
    }

    return jsonResponse({ error: `Unknown action '${action}'` }, 400);
  } catch (err: any) {
    return jsonResponse({ error: err?.message || String(err) }, 500);
  }
});
