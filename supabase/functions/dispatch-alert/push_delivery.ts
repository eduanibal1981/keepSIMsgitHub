export interface PushDevice {
  device_id: string | null;
  onesignal_player_id: string | null;
  fcm_token: string | null;
}

export type PushOutcome = "accepted" | "rejected" | "unknown";

// Create Notification no longer guarantees a recipients field. An accepted
// message ID must never cause another send, even with partial-target warnings.
export function oneSignalOutcome(status: number, body: any): PushOutcome {
  if (status >= 200 && status < 300) {
    if (typeof body?.id === "string" && body.id.trim()) return "accepted";
    if (body?.id === "" || body?.recipients === 0 || body?.errors) return "rejected";
    return "unknown";
  }
  // A timeout/server error might happen AFTER the provider queued the push.
  if (status === 0 || status === 408 || status >= 500) return "unknown";
  return "rejected";
}

// Input is newest first. Deduplicate installs and transport identifiers, never
// platforms: two Android phones are two distinct destinations.
export function uniquePushDevices(rows: PushDevice[]): PushDevice[] {
  const devices = new Set<string>();
  const players = new Set<string>();
  const tokens = new Set<string>();
  return rows.filter((row) => {
    if (!row.onesignal_player_id && !row.fcm_token) return false;
    const key = row.device_id || row.onesignal_player_id || row.fcm_token!;
    const duplicate = devices.has(key) ||
      (!!row.onesignal_player_id && players.has(row.onesignal_player_id)) ||
      (!!row.fcm_token && tokens.has(row.fcm_token));
    devices.add(key);
    if (row.onesignal_player_id) players.add(row.onesignal_player_id);
    if (row.fcm_token) tokens.add(row.fcm_token);
    return !duplicate;
  });
}

// Stable UUID for retrying the same notification/target, including across edge
// invocations. Separate devices need separate keys because their payloads differ.
export async function pushIdempotencyKey(notificationId: string, target: string): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest(
    "SHA-256", new TextEncoder().encode(JSON.stringify([notificationId, target])),
  ));
  digest[6] = (digest[6] & 0x0f) | 0x80; // RFC 9562 UUID v8
  digest[8] = (digest[8] & 0x3f) | 0x80;
  const hex = Array.from(digest.slice(0, 16), (n) => n.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export async function postOneSignal(
  payload: Record<string, unknown>,
  apiKey: string,
  fetcher: typeof fetch = fetch,
  timeoutMs = 5000,
): Promise<{ outcome: PushOutcome; status: number; id?: string; detail: string }> {
  // Retry an ambiguous result once with the SAME idempotency key. Never switch
  // transport after ambiguity: doing so can create a second visible card.
  for (let attempt = 0; attempt < 2; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetcher("https://api.onesignal.com/notifications?c=push", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Key ${apiKey}` },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      const body = await response.json().catch(() => ({}));
      const outcome = oneSignalOutcome(response.status, body);
      if (outcome === "unknown" && attempt === 0) continue;
      return { outcome, status: response.status, id: body?.id,
        detail: JSON.stringify(body) };
    } catch (error) {
      if (attempt === 1) return { outcome: "unknown", status: 0, detail: String(error) };
    } finally {
      clearTimeout(timer);
    }
  }
  throw new Error("Unreachable OneSignal retry state");
}

export async function routePushDevices(
  rows: PushDevice[],
  sendOneSignal: (device: PushDevice) => Promise<PushOutcome>,
  sendFcm: (devices: PushDevice[]) => Promise<void>,
): Promise<void> {
  const fallback: PushDevice[] = [];
  for (const device of uniquePushDevices(rows)) {
    const outcome = device.onesignal_player_id ? await sendOneSignal(device) : "rejected";
    if (outcome === "rejected" && device.fcm_token) fallback.push(device);
  }
  if (fallback.length) await sendFcm(fallback);
}
