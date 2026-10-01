export type TargetOutcome = {
  channel: string;
  target: string;
  state: "accepted_by_provider" | "delivered" | "failed" | "skipped" | "unknown";
  detail: string;
  retryable?: boolean;
};

// Snapshot destination/device identity once. Atomic claims prevent parallel
// dispatches from replaying accepted targets or ambiguous in-flight sends.
export async function deliverTarget(db: any, notificationId: string, channel: string,
  target: string, snapshot: any, send: (saved: any) => Promise<Omit<TargetOutcome, "channel" | "target">>): Promise<TargetOutcome> {
  const identity = { channel, target };
  const { data: claim, error } = await db.rpc("claim_notification_channel_target", {
    p_notification_id: notificationId, p_channel: channel, p_target_key: target, p_snapshot: snapshot,
  });
  if (error || !claim) return { ...identity, state: "failed", retryable: true, detail: "Target could not be claimed; no provider send attempted." };
  const row = claim.target;
  if (!claim.claimed) return { ...identity,
    state: row.state === "attempting" ? "unknown" : row.state,
    retryable: row.retryable === true && row.attempt_count < 3,
    detail: row.detail || "Existing target outcome retained; duplicate withheld." };
  let outcome: Omit<TargetOutcome, "channel" | "target">;
  try { outcome = await send(row.snapshot); }
  catch (_) { outcome = { state: "unknown", detail: "Provider connection ended without a confirmed outcome." }; }
  const { data: persisted, error: persistError } = await db.rpc("finish_notification_channel_target", {
    p_notification_id: notificationId, p_channel: channel, p_target_key: target,
    p_claim_token: claim.claim_token, p_state: outcome.state,
    p_retryable: outcome.retryable === true, p_detail: outcome.detail,
  });
  if (persistError || (persisted !== true && persisted?.persisted !== true)) return { ...identity, state: "unknown",
    detail: "Send attempted; target outcome persistence requires reconciliation." };
  if (persisted?.target) return { ...identity, state: persisted.target.state,
    detail: persisted.target.detail || outcome.detail,
    retryable: persisted.target.retryable === true && persisted.target.attempt_count < 3 };
  return { ...identity, ...outcome };
}

export function summarizeTargets(outcomes: TargetOutcome[]) {
  const failed = outcomes.some((o) => o.state === "failed");
  const unknown = outcomes.some((o) => o.state === "unknown");
  // Known failures may be retried while accepted/unknown targets stay withheld.
  const retryable = outcomes.some((o) => o.state === "failed" && o.retryable === true);
  return { success: !failed && !unknown, state: retryable || failed ? "failed" : unknown ? "unknown" : "complete",
    retryable, outcomes };
}

export function httpOutcome(channel: string, status: number, ok: boolean): Omit<TargetOutcome, "channel" | "target"> {
  return ok
    ? { state: "accepted_by_provider", detail: `${channel} accepted the request (HTTP ${status}); recipient delivery is unconfirmed.` }
    : { state: "failed", retryable: status === 429 || status >= 500,
      detail: `${channel} rejected the request (HTTP ${status}).` };
}

export function escapeHtml(value: unknown): string {
  return String(value || "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
}
