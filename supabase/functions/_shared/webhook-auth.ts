import { EndpointError, safeEqual } from "./endpoint-auth.ts";

// Select a server-controlled origin/path. Forwarded host/proto are untrusted.
// Preserve the original query string: Twilio signs it as part of the full URL.
export function webhookUrl(req: Request, configured: string | undefined, projectUrl: string, slug: string): string {
  const url = configured || (projectUrl ? `${projectUrl}/functions/v1/${slug}` : "");
  if (!url || new URL(url).protocol !== "https:") throw new EndpointError(503, "Webhook URL is not configured");
  const query = new URL(req.url).search;
  if (url.includes("?") && url.slice(url.indexOf("?")) !== query) throw new EndpointError(403, "Webhook URL mismatch");
  return url.includes("?") ? url : url + query;
}

export async function verifyTwilio(req: Request, raw: string, token: string, url: string): Promise<Record<string, string>> {
  if (!token) throw new EndpointError(503, "Webhook authentication is not configured");
  const form = new URLSearchParams(raw);
  const params: Record<string, string> = Object.create(null);
  let input = url;
  for (const name of [...new Set(form.keys())].sort()) {
    const values = [...new Set(form.getAll(name))].sort();
    for (const value of values) input += name + value;
    // Our consumers require scalar fields. Reject ambiguous signed forms.
    if (values.length !== 1) throw new EndpointError(400, "Ambiguous webhook parameters");
    params[name] = values[0];
  }
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(token),
    { name: "HMAC", hash: "SHA-1" }, false, ["sign"]);
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(input));
  const expected = btoa(String.fromCharCode(...new Uint8Array(digest)));
  if (!safeEqual(req.headers.get("x-twilio-signature") || "", expected)) throw new EndpointError(403, "Invalid webhook signature");
  return params;
}

function keyBytes(value: string): Uint8Array {
  // Check hex first; hex strings are also syntactically valid base64.
  if (/^[0-9a-f]{64}$/i.test(value)) return Uint8Array.from(value.match(/../g)!, x => parseInt(x, 16));
  const bytes = Uint8Array.from(atob(value), c => c.charCodeAt(0));
  // Accept only the exact Ed25519 SPKI prefix, not arbitrary ASN.1 data.
  const prefix = "302a300506032b6570032100";
  if (bytes.length === 44 && Array.from(bytes.slice(0, 12), b => b.toString(16).padStart(2, "0")).join("") === prefix) return bytes.slice(12);
  return bytes;
}

export async function verifyTelnyx(req: Request, raw: string, publicKey: string): Promise<void> {
  if (!publicKey) throw new EndpointError(503, "Webhook authentication is not configured");
  let key: CryptoKey;
  try {
    const bytes = keyBytes(publicKey.trim());
    if (bytes.length !== 32) throw new Error();
    key = await crypto.subtle.importKey("raw", new Uint8Array(bytes), "Ed25519", false, ["verify"]);
  } catch (_) { throw new EndpointError(503, "Webhook verification key is invalid"); }
  const timestamp = req.headers.get("telnyx-timestamp") || "";
  if (!/^\d+$/.test(timestamp) || Math.abs(Date.now() / 1000 - Number(timestamp)) > 300) throw new EndpointError(401, "Invalid webhook timestamp");
  let valid = false;
  try {
    const signature = Uint8Array.from(atob(req.headers.get("telnyx-signature-ed25519") || ""), c => c.charCodeAt(0));
    valid = signature.length === 64 && await crypto.subtle.verify("Ed25519", key, signature,
      new TextEncoder().encode(`${timestamp}|${raw}`));
  } catch (_) { /* Invalid encoding/signature fails closed. */ }
  if (!valid) throw new EndpointError(401, "Invalid webhook signature");
}
