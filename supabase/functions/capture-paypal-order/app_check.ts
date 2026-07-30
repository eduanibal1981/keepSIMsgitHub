// ============================================================================
// G10 — Firebase App Check verification, server side.
//
// ⚠️ THIS FILE IS DUPLICATED, DELIBERATELY, in create-paypal-order/ and
//    capture-paypal-order/. The two copies must stay byte-identical; diff them
//    if you touch either. The `_shared/` import pattern is not used because the
//    MCP `deploy_edge_function` path bundles a flat file list per function and a
//    silently-stale shared copy on a money path is worse than a visible
//    duplicate.
//
// What it does: verifies the `X-Firebase-AppCheck` header is a JWT that Google
// signed for THIS Firebase project, using the public JWKS at
// firebaseappcheck.googleapis.com. It does NOT trust the header's presence or
// its contents — an unverified App Check header is worth exactly nothing, and
// treating it as proof is the mistake this function exists to avoid.
//
// What it deliberately does not do: decide. It returns an outcome and lets the
// caller consult `app_check_should_enforce(platform)`, so enforcement lives in
// one place (system_configs) rather than in two deployed bundles.
// ============================================================================

/** The Firebase project number. Public — it ships inside every APK
 *  (android/app/google-services.json). Overridable by env for a second project. */
const PROJECT_NUMBER = Deno.env.get("FIREBASE_PROJECT_NUMBER") ?? "1679369602";
const JWKS_URL = "https://firebaseappcheck.googleapis.com/v1/jwks";
const ISSUER = `https://firebaseappcheck.googleapis.com/${PROJECT_NUMBER}`;
const AUDIENCE = `projects/${PROJECT_NUMBER}`;

export type AppCheckOutcome = "pass" | "missing" | "invalid" | "error";

export interface AppCheckResult {
  outcome: AppCheckOutcome;
  /** The attested app id (`sub`), present only on a pass. */
  appId?: string;
  /** Why it failed. Safe to log; never contains the token. */
  detail?: Record<string, unknown>;
}

interface Jwk {
  kid?: string;
  kty?: string;
  alg?: string;
  n?: string;
  e?: string;
}

// One fetch per isolate, not per request. Google rotates keys rarely and a
// cache miss on an unknown kid re-fetches, so a stale cache cannot cause a
// false "invalid".
let jwksCache: { keys: Jwk[]; fetchedAt: number } | null = null;
const JWKS_TTL_MS = 6 * 60 * 60 * 1000;

async function getJwks(forceRefresh = false): Promise<Jwk[]> {
  const fresh = jwksCache && Date.now() - jwksCache.fetchedAt < JWKS_TTL_MS;
  if (fresh && !forceRefresh) return jwksCache!.keys;

  const res = await fetch(JWKS_URL);
  if (!res.ok) throw new Error(`JWKS fetch failed: ${res.status}`);
  const body = await res.json();
  const keys: Jwk[] = Array.isArray(body?.keys) ? body.keys : [];
  if (keys.length === 0) throw new Error("JWKS contained no keys");
  jwksCache = { keys, fetchedAt: Date.now() };
  return keys;
}

function b64urlToBytes(s: string): Uint8Array {
  const pad = s.length % 4 === 0 ? "" : "=".repeat(4 - (s.length % 4));
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/") + pad;
  const raw = atob(b64);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

function b64urlToJson(s: string): Record<string, unknown> {
  return JSON.parse(new TextDecoder().decode(b64urlToBytes(s)));
}

/**
 * Verifies an App Check token. Never throws: a verification that cannot run is
 * an `error` outcome, not a 500 on a money path.
 */
export async function verifyAppCheckToken(token: string | null): Promise<AppCheckResult> {
  if (!token || token.trim() === "") return { outcome: "missing" };

  try {
    const parts = token.split(".");
    if (parts.length !== 3) return { outcome: "invalid", detail: { reason: "not_a_jwt" } };

    const header = b64urlToJson(parts[0]) as { alg?: string; typ?: string; kid?: string };

    // RS256 only. Accepting `alg` from the token is how alg-confusion works, so
    // this is an allow-list of exactly one value, checked before any key lookup.
    if (header.alg !== "RS256") {
      return { outcome: "invalid", detail: { reason: "bad_alg", alg: header.alg ?? null } };
    }
    if (header.typ && header.typ !== "JWT") {
      return { outcome: "invalid", detail: { reason: "bad_typ", typ: header.typ } };
    }

    let keys = await getJwks();
    let jwk = keys.find((k) => k.kid === header.kid);
    if (!jwk) {
      // Unknown kid: Google may have rotated. One forced refresh, then give up.
      keys = await getJwks(true);
      jwk = keys.find((k) => k.kid === header.kid);
    }
    if (!jwk || jwk.kty !== "RSA" || !jwk.n || !jwk.e) {
      return { outcome: "invalid", detail: { reason: "unknown_kid", kid: header.kid ?? null } };
    }

    const key = await crypto.subtle.importKey(
      "jwk",
      { kty: "RSA", n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );

    const signed = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
    const ok = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      key,
      b64urlToBytes(parts[2]),
      signed,
    );
    if (!ok) return { outcome: "invalid", detail: { reason: "bad_signature" } };

    // Signature is good; now the claims. Order matters — none of these are
    // meaningful before the signature check above.
    const claims = b64urlToJson(parts[1]) as {
      iss?: string; aud?: string | string[]; exp?: number; iat?: number; sub?: string;
    };

    if (claims.iss !== ISSUER) {
      return { outcome: "invalid", detail: { reason: "bad_iss", iss: claims.iss ?? null } };
    }

    const aud = Array.isArray(claims.aud) ? claims.aud : claims.aud ? [claims.aud] : [];
    if (!aud.includes(AUDIENCE)) {
      return { outcome: "invalid", detail: { reason: "bad_aud", aud } };
    }

    // 60s of clock skew, the same allowance Google's own libraries use.
    const now = Math.floor(Date.now() / 1000);
    if (typeof claims.exp !== "number" || claims.exp + 60 < now) {
      return { outcome: "invalid", detail: { reason: "expired", exp: claims.exp ?? null } };
    }
    if (typeof claims.iat === "number" && claims.iat - 60 > now) {
      return { outcome: "invalid", detail: { reason: "issued_in_future", iat: claims.iat } };
    }

    return { outcome: "pass", appId: claims.sub };
  } catch (err) {
    // JWKS unreachable, malformed base64, WebCrypto refusing the key: all
    // "we could not tell", which must never be mistaken for "it failed".
    return {
      outcome: "error",
      detail: { reason: "verification_error", message: (err as Error)?.message ?? String(err) },
    };
  }
}

/** The header Firebase's client SDKs send it in. */
export const APP_CHECK_HEADER = "x-firebase-appcheck";
