import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1. Check Database connectivity
    const { error: dbErr } = await supabase
      .from("system_configs")
      .select("config_key")
      .limit(1);

    if (dbErr) {
      throw new Error(`DB health check failed: ${dbErr.message}`);
    }

    // 2. Check Worker Heartbeat freshness
    const { data: hbRow } = await supabase
      .from("system_configs")
      .select("updated_at")
      .eq("config_key", "WORKER_ESIM_FULFILLMENT_HEARTBEAT")
      .maybeSingle();

    let workerStatus = "unknown";
    let isStale = true;
    let staleMinutes = -1;

    if (hbRow && hbRow.updated_at) {
      const lastSeen = new Date(hbRow.updated_at).getTime();
      const now = new Date().getTime();
      staleMinutes = Math.round((now - lastSeen) / 60000);
      if (staleMinutes <= 15) {
        workerStatus = "online";
        isStale = false;
      } else {
        workerStatus = "stale";
      }
    } else {
      workerStatus = "missing";
    }

    const isHealthy = !isStale && workerStatus === "online";
    const httpStatus = isHealthy ? 200 : 503;

    return new Response(
      JSON.stringify({
        status: isHealthy ? "healthy" : "degraded",
        database: "online",
        worker: workerStatus,
        stale_minutes: staleMinutes,
        timestamp: new Date().toISOString(),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: httpStatus,
      }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({
        status: "unhealthy",
        error: err.message,
        timestamp: new Date().toISOString(),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
