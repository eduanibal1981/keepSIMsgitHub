// Drains durable notification jobs. A request with an ambiguous outcome is
// quarantined as unknown; it is never retried automatically.
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { quietHoursReleaseTime } from "./quiet_hours.ts";

type Job = {
  id: string;
  notification_id: string;
  payload: Record<string, unknown>;
  attempt_count: number;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db = createClient(supabaseUrl, serviceKey);

async function finish(
  id: string,
  state: "complete" | "unknown" | "failed" | "canceled",
  error?: string,
  response?: Record<string, unknown>,
  retryable = false,
) {
  const { data, error: rpcError } = await db.rpc("finish_notification_dispatch_job", {
    p_id: id,
    p_state: state,
    p_error: error ?? null,
    p_response: response ?? null,
    p_retryable: retryable,
  });
  if (rpcError || data !== true) {
    throw new Error(`Could not finish dispatch job ${id}: ${rpcError?.message ?? "lease not held"}`);
  }
}

async function currentChannels(job: Job): Promise<string[] | null> {
  const payload = job.payload;
  const userId = String(payload.user_id ?? "");
  const category = String(payload.category ?? "");
  const original = Array.isArray(payload.channels)
    ? payload.channels.filter((value): value is string => typeof value === "string")
    : [];
  if (!userId || !category || !original.length) return null;

  const { data: notification, error: notificationError } = await db
    .from("notifications")
    .select("id, user_id, category, sim_line_id, expires_at")
    .eq("id", job.notification_id)
    .maybeSingle();
  if (notificationError) throw notificationError;
  if (!notification || notification.user_id !== userId || notification.category !== category ||
      (notification.expires_at && Date.parse(notification.expires_at) <= Date.now())) return null;

  const [settingsResult, channelsResult, catalogResult, lineResult] = await Promise.all([
    db.from("alert_settings").select("is_enabled,channels").eq("user_id", userId).eq("category", category).maybeSingle(),
    db.from("notification_channels").select("channel_type,is_enabled").eq("user_id", userId),
    db.from("notification_channel_catalog").select("channel_key,is_globally_enabled,min_tier"),
    notification.sim_line_id ? db.from("sim_lines").select("user_id,status").eq("id", notification.sim_line_id).maybeSingle()
      : Promise.resolve({ data: null, error: null }),
  ]);
  for (const result of [settingsResult, channelsResult, catalogResult, lineResult]) if (result.error) throw result.error;
  if (settingsResult.data?.is_enabled === false || (!settingsResult.data && category === "promo")) return null;
  if (notification.sim_line_id && (!lineResult.data || lineResult.data.user_id !== userId ||
      ["deleted", "canceled", "archived"].includes(lineResult.data.status))) return null;

  if (payload.event_type === "line_deactivation_imminent") {
    if (!notification.sim_line_id || !payload.source_event_key) return null;
    const { error: refreshError } = await db.rpc("calculate_sim_line_alert_clock", {
      p_sim_line_id: notification.sim_line_id,
    });
    if (refreshError) throw refreshError;
    const { data: clock, error: clockError } = await db
      .from("sim_line_alert_clock_states")
      .select("state, is_within_48h, alert_cycle_token")
      .eq("sim_line_id", notification.sim_line_id)
      .maybeSingle();
    if (clockError) throw clockError;
    const currentKey = `deactivation_48h:${notification.sim_line_id}:${clock?.alert_cycle_token ?? ""}`;
    if (clock?.state !== "eligible" || clock?.is_within_48h !== true ||
        currentKey !== payload.source_event_key) return null;
  }

  // Revalidate ownership, cycle and freshness after quiet-hours/retry delays.
  if (String(payload.event_type || "").startsWith("esim_")) {
    const { data: current, error } = await db.rpc("service_esim_alert_is_current", {
      p_notification_id: job.notification_id,
    });
    if (error) throw error;
    if (current !== true) return null;
  }

  const categoryChannels = settingsResult.data?.channels as string[] | null;
  const enabled = new Map((channelsResult.data ?? []).map((row) =>
    [row.channel_type as string, row.is_enabled === true]));
  const global = new Set((catalogResult.data ?? [])
    .filter((row) => row.is_globally_enabled)
    .map((row) => row.channel_key as string));
  const candidates = original.filter((channel) =>
    (!String(payload.event_type || "").startsWith("esim_") || channel === "push") && global.has(channel) &&
    (!categoryChannels || categoryChannels.includes(channel)) &&
    (enabled.get(channel) === true || (channel === "push" && !enabled.has("push"))));
  const eligibility = await Promise.all(candidates.map(async (channel) => {
    const { data, error } = await db.rpc("notification_channel_eligible", {
      p_user_id: userId, p_sim_line_id: notification.sim_line_id || null,
      p_channel: channel, p_event_type: payload.event_type || null,
    });
    if (error) throw error;
    return data === true ? channel : null;
  }));
  return eligibility.filter((channel): channel is string => channel !== null);

}

async function quietHoursRelease(job: Job): Promise<Date | null> {
  const payload = job.payload;
  if (payload.event_type === "notification_test") return null;
  if (payload.category === "line_critical" ||
      payload.event_type === "line_deactivation_imminent") return null;
  const userId = String(payload.user_id ?? "");
  const { data, error } = await db.from("user_preferences")
    .select("quiet_hours_start, quiet_hours_end, notification_timezone")
    .eq("user_id", userId).maybeSingle();
  if (error) throw error;
  if (!data?.quiet_hours_start || !data.quiet_hours_end) return null;
  // Saved switches from older builds have no time zone. Keep sending routine
  // alerts until the updated app records the user's actual IANA zone.
  if (!data.notification_timezone) return null;
  return quietHoursReleaseTime(new Date(), data.notification_timezone,
    data.quiet_hours_start, data.quiet_hours_end);
}

async function processJob(job: Job) {
  try {
    const channels = await currentChannels(job);
    if (!channels?.length) {
      await finish(job.id, "canceled", "No channels remain enabled or event is stale");
      return "canceled";
    }
    const release = await quietHoursRelease(job);
    if (release) {
      const { data, error } = await db.rpc("defer_notification_dispatch_job", {
        p_id: job.id, p_until: release.toISOString(),
      });
      if (error || data !== true) throw new Error(`Could not defer quiet-hours job: ${error?.message ?? "lease not held"}`);
      return "deferred";
    }
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 45000);
    let response: Response;
    try {
      response = await fetch(`${supabaseUrl}/functions/v1/dispatch-alert`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({ ...job.payload, channels }),
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeout);
    }
    const result = await response.json().catch(() => ({})) as Record<string, unknown>;
    if (response.ok && result.success === true) {
      await finish(job.id, "complete", undefined, result);
      return "complete";
    }
    if (response.ok && Array.isArray(result.outcomes)) {
      const state = result.state === "unknown" ? "unknown" : "failed";
      await finish(job.id, state, "One or more channel targets were not accepted", result, result.retryable === true);
      return result.retryable === true && job.attempt_count < 3 ? "retrying" : state;
    }
    // Even an HTTP rate limit can originate after a provider accepted a send.
    // Quarantine it until there is evidence that replay cannot duplicate it.
    if (response.status === 400 || response.status === 401 || response.status === 403) {
      await finish(job.id, "failed", `Dispatcher rejected HTTP ${response.status}`, result);
      return "failed";
    }
    await finish(job.id, "unknown", `Dispatcher HTTP ${response.status}; send outcome unknown`, result);
    return "unknown";
  } catch (error) {
    // A network error may occur after the dispatcher reached a provider.
    try { await finish(job.id, "unknown", String(error)); }
    catch (finishError) { console.error("Could not quarantine job", job.id, finishError); }
    return "unknown";
  }
}

serve(async (request) => {
  const bearer = request.headers.get("Authorization");
  if (bearer !== `Bearer ${serviceKey}`) {
    const { data: secret } = await db.rpc("get_internal_secret", {
      p_name: "dispatch_shared_secret",
    });
    if (!secret || request.headers.get("x-keep-sims-secret") !== secret) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }
  }

  const { data: jobs, error } = await db.rpc("claim_notification_dispatch_jobs", { p_limit: 5 });
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
  const outcomes: Record<string, number> = {};
  const states = await Promise.all(((jobs ?? []) as Job[]).map(processJob));
  for (const state of states) {
    outcomes[state] = (outcomes[state] ?? 0) + 1;
  }
  return new Response(JSON.stringify({ success: true, claimed: jobs?.length ?? 0, outcomes }), {
    headers: { "Content-Type": "application/json" },
  });
});
