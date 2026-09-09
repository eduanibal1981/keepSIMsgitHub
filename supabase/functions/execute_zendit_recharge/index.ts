import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// 410 GONE - This direct recharge endpoint is permanently retired.
// All recharge executions and setup verifications must be processed canonically
// through the topup_executions pipeline and authoritative background workers.
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  return new Response(
    JSON.stringify({
      success: false,
      error: 'HTTP 410 Gone',
      message: 'execute_zendit_recharge has been permanently retired. Recharge execution goes through the topup_executions worker pipeline.',
    }),
    {
      status: 410,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  );
});
