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

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const payload = await req.json();
    const {
      user_id,
      did_id,
      caller_number,
      caller_name = "Unknown Caller",
      audio_url,
      duration_seconds = 0,
      transcript,
      language = "en",
    } = payload;

    if (!user_id || !caller_number || !audio_url) {
      return jsonResponse({ error: "Missing required fields: user_id, caller_number, audio_url" }, 400);
    }

    const generatedTranscript = transcript || "Audio message recorded. AI transcription in progress.";

    // 1. Insert into voicemail_messages
    const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/voicemail_messages`, {
      method: "POST",
      headers: { ...serviceHeaders, "Prefer": "return=representation" },
      body: JSON.stringify({
        user_id,
        did_id: did_id || null,
        caller_number,
        caller_name,
        audio_url,
        duration_seconds,
        transcript: generatedTranscript,
        language,
        status: "transcribed",
        is_read: false,
      }),
    });

    if (!insertRes.ok) {
      const errText = await insertRes.text();
      return jsonResponse({ error: `Failed to store voicemail: ${errText}` }, 500);
    }

    const rows = await insertRes.json();
    const voicemail = rows[0];

    // 2. Dispatch Push Notification via dispatch-alert
    try {
      await fetch(`${SUPABASE_URL}/functions/v1/dispatch-alert`, {
        method: "POST",
        headers: serviceHeaders,
        body: JSON.stringify({
          category: "voip_call",
          user_id,
          title: `New Voicemail from ${caller_name || caller_number}`,
          body: generatedTranscript.length > 80 ? `${generatedTranscript.substring(0, 80)}...` : generatedTranscript,
          action_url: `/calling/voicemail/${voicemail.id}`,
          voip_payload: {
            type: "NEW_VOICEMAIL",
            voicemail_id: voicemail.id,
            caller_number,
            caller_name,
          },
        }),
      }).catch(() => {});
    } catch (_) {}

    return jsonResponse({ success: true, voicemail }, 200);
  } catch (err: any) {
    return jsonResponse({ error: err?.message || String(err) }, 500);
  }
});
