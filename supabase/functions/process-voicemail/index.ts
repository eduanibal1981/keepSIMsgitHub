import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { EndpointError, requireService } from "../_shared/endpoint-auth.ts";
import { trustedDatabase, withWebhookEvent } from "../_shared/webhook-events.ts";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db = trustedDatabase(url, serviceKey);
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json" },
});

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    requireService(req, serviceKey);
    const raw = await req.text();
    let payload;
    try { payload = JSON.parse(raw); } catch (_) { throw new EndpointError(400, "Invalid JSON"); }
    const { recording_id, call_record_id, did_id, audio_url } = payload;
    if (typeof recording_id !== "string" || !recording_id || recording_id.length > 200 ||
        (!call_record_id && !did_id) || typeof audio_url !== "string" || !/^https:\/\//.test(audio_url)) {
      throw new EndpointError(400, "A recording ID, call or DID record, and HTTPS audio URL are required");
    }
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if ((call_record_id && !uuid.test(call_record_id)) || (did_id && !uuid.test(did_id))) throw new EndpointError(400, "Invalid target identifier");
    const call = call_record_id ? (await db(`call_records?id=eq.${call_record_id}&select=id,user_id,caller_number,destination_number`))[0] : null;
    const did = did_id ? (await db(`virtual_did_numbers?id=eq.${did_id}&select=id,user_id,phone_number`))[0] : null;
    if ((call_record_id && !call) || (did_id && !did)) throw new EndpointError(404, "Target not found");
    const owner = call?.user_id || did?.user_id;
    if (!owner || (payload.user_id && payload.user_id !== owner) ||
        (call && did && (call.user_id !== did.user_id || call.destination_number !== did.phone_number))) {
      throw new EndpointError(403, "Voicemail target mismatch");
    }
    const caller = call?.caller_number || payload.caller_number;
    if (typeof caller !== "string" || !caller) throw new EndpointError(400, "Missing caller number");
    return await withWebhookEvent(db, "voicemail", recording_id, call_record_id || did_id, payload, async () => {
      const existing = await db(`voicemail_messages?source_recording_id=eq.${encodeURIComponent(recording_id)}&select=id`);
      if (existing.length) return json({ success: true, duplicate: true });
      const transcript = payload.transcript || "Audio message recorded. AI transcription in progress.";
      const [voicemail] = await db("voicemail_messages", "POST", {
        user_id: owner, did_id: did_id || null, source_recording_id: recording_id,
        caller_number: caller, caller_name: payload.caller_name || "Unknown Caller", audio_url,
        duration_seconds: payload.duration_seconds || 0, transcript,
        language: payload.language || "en", status: "transcribed", is_read: false,
      });
      // Best-effort notification only for the first insert; retries never push twice.
      await fetch(`${url}/functions/v1/dispatch-alert`, {
        method: "POST", headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({ category: "voip_call", user_id: owner, title: "New Voicemail",
          body: String(transcript).slice(0, 80), action_url: `/calling/voicemail/${voicemail.id}`,
          voip_payload: { type: "NEW_VOICEMAIL", voicemail_id: voicemail.id, caller_number: caller } }),
      }).catch(() => {});
      return json({ success: true, voicemail });
    });
  } catch (error) {
    return json({ error: error instanceof EndpointError ? error.message : "Voicemail processing unavailable" },
      error instanceof EndpointError ? error.status : 503);
  }
});
