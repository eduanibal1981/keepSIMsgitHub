import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { safeEqual } from "../_shared/endpoint-auth.ts";

const headers = { "Content-Type": "application/json" };
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Enumerate before removing, so deleting a page cannot shift the next offset.
async function clearStorage(client: any, bucket: string, userId: string) {
  const pending = [{ path: userId, depth: 0 }], files: string[] = [];
  let entries = 0;
  while (pending.length) {
    const folder = pending.pop()!;
    if (folder.depth > 20) throw new Error("storage_failed");
    for (let offset = 0;; offset += 100) {
      const result = await client.storage.from(bucket).list(folder.path, { limit: 100, offset, sortBy: { column: "name", order: "asc" } });
      if (result.error) {
        if (Number(result.error.statusCode || result.error.status) === 404) break;
        throw new Error("storage_failed");
      }
      if (!Array.isArray(result.data)) throw new Error("storage_failed");
      for (const file of result.data) {
        if (++entries > 10000 || !file.name || /[\/\\]/.test(file.name) || file.name === "." || file.name === "..") throw new Error("storage_failed");
        const path = `${folder.path}/${file.name}`;
        if (file.id == null && file.metadata == null) pending.push({ path, depth: folder.depth + 1 });
        else files.push(path);
      }
      if (result.data.length < 100) break;
    }
  }
  for (let offset = 0; offset < files.length; offset += 100) {
    const result = await client.storage.from(bucket).remove(files.slice(offset, offset + 100));
    if (result.error) throw new Error("storage_failed");
  }
}

export async function handlePurgeRequest(req: Request): Promise<Response> {
  const reply = (status: number, body: object) => new Response(JSON.stringify(body), { status, headers });
  if (req.method !== "POST") return reply(405, { success: false, error: "Method not allowed" });
  const url = Deno.env.get("SUPABASE_URL"), key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return reply(503, { success: false, error: "Purge service unavailable" });
  const client = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  let jobId: string | undefined, token: string | undefined;
  let failure = "completion_failed";
  try {
    const secret = await client.rpc("get_internal_secret", { p_name: "dispatch_shared_secret" });
    if (secret.error) return reply(503, { success: false, error: "Purge authentication unavailable" });
    if (typeof secret.data !== "string" || !secret.data || !safeEqual(req.headers.get("x-keep-sims-secret") || "", secret.data))
      return reply(401, { success: false, error: "Unauthorized" });
    let body: any;
    try { body = await req.json(); } catch { return reply(400, { success: false, error: "Invalid request" }); }
    if (!body || typeof body.job_id !== "string" || !uuid.test(body.job_id) || body.user_id || body.admin_purge)
      return reply(400, { success: false, error: "A persisted purge job is required" });
    jobId = body.job_id;
    const claim = await client.rpc("claim_account_purge_job", { p_job_id: jobId });
    if (claim.error) throw new Error("completion_failed");
    if (!claim.data?.claimed) {
      if (claim.data?.state === "completed") return reply(200, { success: true, status: "completed", job_id: jobId });
      return reply(claim.data?.state === "busy" ? 202 : 409, { success: false, status: claim.data?.state || "unavailable", job_id: jobId });
    }
    token = claim.data.claim_token;
    const userId = claim.data.user_id;
    if (!uuid.test(userId || "") || !uuid.test(token || "")) throw new Error("completion_failed");
    failure = "storage_failed";
    for (const bucket of ["ticket-attachments", "support_attachments"]) await clearStorage(client, bucket, userId);
    failure = "auth_failed";
    const deleted = await client.auth.admin.deleteUser(userId);
    if (deleted.error && Number(deleted.error.status) !== 404 && deleted.error.code !== "user_not_found") throw new Error("auth_failed");
    failure = "completion_failed";
    const finished = await client.rpc("finish_account_purge_job", {
      p_job_id: jobId, p_claim_token: token, p_success: true, p_note: null,
    });
    if (finished.error || finished.data !== true) throw new Error("completion_failed");
    return reply(200, { success: true, status: "completed", job_id: jobId });
  } catch {
    if (jobId && token) {
      try {
        // Couples failed state and audit using the persisted authorized actor.
        // This replaces the invalid generic admin_log/p_reason invocation.
        const recorded = await client.rpc("finish_account_purge_job", {
          p_job_id: jobId, p_claim_token: token, p_success: false, p_note: failure,
        });
        if (recorded.error || recorded.data !== true) console.warn("Purge failure audit could not be persisted");
      } catch { console.warn("Purge failure audit could not be persisted"); }
    }
    return reply(503, { success: false, error: failure, job_id: jobId });
  }
}

serve(handlePurgeRequest);
