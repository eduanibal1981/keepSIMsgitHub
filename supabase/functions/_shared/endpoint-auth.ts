// Handler authentication remains mandatory even when the gateway verifies JWTs.
export class EndpointError extends Error {
  readonly status: number;
  constructor(status: number, message: string) { super(message); this.status = status; }
}

export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return difference === 0;
}

export function bearer(req: Request): string {
  const match = /^Bearer ([^\s]+)$/i.exec(req.headers.get("authorization") || "");
  if (!match) throw new EndpointError(401, "Unauthorized");
  return match[1];
}

export function requireService(req: Request, serviceKey: string): void {
  if (!serviceKey) throw new EndpointError(503, "Authentication is not configured");
  // Compare against the actual server credential; never trust a decoded role.
  if (!safeEqual(bearer(req), serviceKey)) throw new EndpointError(401, "Unauthorized");
}

export async function requireAdmin(req: Request, url: string, serviceKey: string): Promise<void> {
  if (!url || !serviceKey) throw new EndpointError(503, "Authentication is not configured");
  const token = bearer(req);
  if (safeEqual(token, serviceKey)) return; // Internal callers are not Auth users.
  const headers = { apikey: serviceKey, Authorization: `Bearer ${token}` };
  const response = await fetch(`${url}/auth/v1/user`, { headers });
  if (!response.ok) throw new EndpointError(response.status >= 500 ? 503 : 401, "Unauthorized");
  const user = await response.json();
  if (!user.id || user.app_metadata?.is_power_user !== true) throw new EndpointError(403, "Admin access required");
  // Use the existing server contract, including JWT claims and suspension checks.
  const admin = await fetch(`${url}/rest/v1/rpc/assert_admin`, {
    method: "POST", headers: { ...headers, "Content-Type": "application/json" }, body: "{}",
  });
  if (!admin.ok) throw new EndpointError(admin.status >= 500 ? 503 : 403, "Admin access required");
}
