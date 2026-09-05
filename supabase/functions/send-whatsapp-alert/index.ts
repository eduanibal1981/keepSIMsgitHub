import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WHATSAPP_API_KEY =
  Deno.env.get("WHATSAPP_VPS_API_KEY") ||
  Deno.env.get("WHATSAPP_ALERTS_KEY") ||
  "super_secret_alerts_key";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Authenticate caller
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(jwt);

    if (authErr || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    const { phone, message } = await req.json();
    if (!phone || !message) {
      return new Response(JSON.stringify({ error: "phone and message are required" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const cleanPhone = phone.replace(/[^0-9]/g, "");
    let baseUrl: string | null = null;

    // 2. Resolve country-specific WhatsApp server URL
    try {
      const { data: countries } = await supabase
        .from("countries")
        .select("dialing_code, whatsapp_server_url");

      if (countries && Array.isArray(countries)) {
        for (const row of countries) {
          const code = (row.dialing_code || "").replace(/[^0-9]/g, "");
          if (code && cleanPhone.startsWith(code) && row.whatsapp_server_url) {
            baseUrl = row.whatsapp_server_url;
            break;
          }
        }
      }
    } catch (_) {
      // ignore lookup error and fallback
    }

    // 3. Fallback to default WhatsApp server from system_configs or env
    if (!baseUrl) {
      try {
        const { data: config } = await supabase
          .from("system_configs")
          .select("config_value")
          .eq("config_key", "DEFAULT_WHATSAPP_SERVER_URL")
          .maybeSingle();

        if (config?.config_value) {
          baseUrl = config.config_value;
        }
      } catch (_) {}
    }

    if (!baseUrl) {
      baseUrl = Deno.env.get("DEFAULT_WHATSAPP_SERVER_URL") || null;
    }

    if (!baseUrl) {
      return new Response(
        JSON.stringify({ error: "No WhatsApp Server configured" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 503,
        },
      );
    }

    if (!baseUrl.endsWith("/send")) {
      baseUrl = baseUrl.endsWith("/") ? `${baseUrl}send` : `${baseUrl}/send`;
    }

    // 4. Send request to WhatsApp VPS server
    const vpsRes = await fetch(baseUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": WHATSAPP_API_KEY,
      },
      body: JSON.stringify({ phone, message }),
    });

    const vpsData = await vpsRes.json().catch(() => ({}));
    const success = vpsData.success === true || vpsRes.ok;

    return new Response(
      JSON.stringify({ success, data: vpsData }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: vpsRes.status,
      },
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
