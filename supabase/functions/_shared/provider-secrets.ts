// Server-only. Never import into a client bundle or return resolved values.
export class ProviderConfigurationError extends Error {
  readonly code = "PROVIDER_NOT_CONFIGURED";
  constructor() { super("Provider credentials are unavailable. Contact an administrator."); }
}

type SecretClient = {
  rpc(name: string, args: Record<string, unknown>): PromiseLike<{ data: unknown; error: unknown }>;
};

const allowedKeys = new Set([
  "PAYPAL_CLIENT_ID", "PAYPAL_CLIENT_SECRET",
  "TELNYX_API_KEY", "TWILIO_ACCOUNT_SID", "TWILIO_AUTH_TOKEN",
  "ZENDIT_API_SECRET", "DTONE_API_KEY", "DTONE_API_SECRET",
  "FIRSTY_CLIENT_ID", "FIRSTY_CLIENT_SECRET", "TURN_SHARED_SECRET",
  "TURN_USERNAME", "TURN_CREDENTIAL",
]);

// Existing eSIM configuration used this Vault name before the admin registry.
// A canonical replacement always wins; an unavailable Vault never falls back.
const vaultAliases: Record<string, string[]> = {
  ZENDIT_API_SECRET: ["zendit_api_key"],
};

/** Server-only adapter for handlers that use REST rather than the JS SDK. */
export function providerSecretClient(url: string, serviceKey: string): SecretClient {
  return {
    async rpc(name, args) {
      if (!url || !serviceKey || name !== "get_internal_secret") {
        throw new ProviderConfigurationError();
      }
      const response = await fetch(`${url}/rest/v1/rpc/get_internal_secret`, {
        method: "POST",
        headers: {
          apikey: serviceKey, Authorization: `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(args),
        signal: AbortSignal.timeout(10000),
      });
      if (!response.ok) throw new ProviderConfigurationError();
      return { data: await response.json(), error: null };
    },
  };
}

function usable(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed || /^<.*>$/.test(trimmed) || /^(changeme|replace[_ -]?me|your[_ -].*|placeholder)$/i.test(trimmed)) return null;
  return trimmed;
}

export async function readProviderSecret(
  client: SecretClient,
  key: string,
  aliases: string[] = [],
): Promise<string | null> {
  if (!allowedKeys.has(key)) throw new ProviderConfigurationError();
  // Vault wins immediately after an admin replacement. A Vault error must not
  // silently reactivate a stale environment credential.
  for (const name of [key, ...(vaultAliases[key] ?? [])]) {
    let result;
    try { result = await client.rpc("get_internal_secret", { p_name: name }); }
    catch (_) { throw new ProviderConfigurationError(); }
    if (result.error) throw new ProviderConfigurationError();
    if (result.data !== null && result.data !== undefined) {
      const secret = usable(result.data);
      if (!secret) throw new ProviderConfigurationError();
      return secret;
    }
  }
  for (const name of [key, ...aliases]) {
    const secret = usable(Deno.env.get(name));
    if (secret) return secret;
  }
  return null;
}

export async function requireProviderSecret(
  client: SecretClient,
  key: string,
  aliases: string[] = [],
): Promise<string> {
  const value = await readProviderSecret(client, key, aliases);
  if (!value) throw new ProviderConfigurationError();
  return value;
}
