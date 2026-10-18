import { ProviderConfigurationError, readProviderSecret } from "./provider-secrets.ts";

type SecretClient = Parameters<typeof readProviderSecret>[0];
type IceServer = { urls: string[]; username?: string; credential?: string };

/** Resolve only operator-provisioned relay credentials; never use a public relay. */
export async function generateIceServers(
  client: SecretClient,
  userId: string,
): Promise<{ iceServers: IceServer[]; hasTurn: true }> {
  const servers: IceServer[] = [{
    urls: ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"],
  }];
  const turnSecret = await readProviderSecret(client, "TURN_SHARED_SECRET", ["COTURN_SHARED_SECRET"]);
  if (turnSecret) {
    const turnHost = Deno.env.get("TURN_HOST") || Deno.env.get("COTURN_HOST") || "34.40.33.208";
    const username = `${Math.floor(Date.now() / 1000) + 14400}:${userId}`;
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw", encoder.encode(turnSecret), { name: "HMAC", hash: "SHA-1" }, false, ["sign"],
    );
    const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(username));
    const credential = btoa(String.fromCharCode(...new Uint8Array(signature)));
    const udpPort = Deno.env.get("TURN_PORT") || "3478";
    const tlsPort = Deno.env.get("TURN_TLS_PORT") || "443";
    servers.push({
      urls: [
        `turn:${turnHost}:${udpPort}?transport=udp`,
        `turn:${turnHost}:${udpPort}?transport=tcp`,
        `turns:${turnHost}:${tlsPort}?transport=tcp`,
      ],
      username,
      credential,
    });
    return { iceServers: servers, hasTurn: true };
  }

  const urls = (Deno.env.get("TURN_URLS") || "").split(",").map((url) => url.trim()).filter(Boolean);
  const [username, credential] = await Promise.all([
    readProviderSecret(client, "TURN_USERNAME"),
    readProviderSecret(client, "TURN_CREDENTIAL"),
  ]);
  if (!urls.length || urls.some((url) => !/^turns?:[^\s]+$/.test(url)) || !username || !credential) {
    throw new ProviderConfigurationError();
  }
  servers.push({ urls, username, credential });
  return { iceServers: servers, hasTurn: true };
}
