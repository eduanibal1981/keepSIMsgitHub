// Credentials belong to the profile selected in Admin. Legacy environment
// credentials are permitted only for explicitly marked, migrated profiles.
export async function profileSecret(db: any, profile: any, kind: "token" | "key" | "app_secret" | "verify"): Promise<string | null> {
  const meta = profile.connection_metadata || {};
  const settings = {
    token: ["access_token_vault_id", `wa_meta_token_${profile.id}`, "WABA_ACCESS_TOKEN"],
    key: ["auth_secret_vault_id", `wa_baileys_key_${profile.id}`, "WHATSAPP_VPS_API_KEY"],
    app_secret: ["app_secret_vault_id", `wa_meta_app_secret_${profile.id}`, "WABA_APP_SECRET"],
    verify: ["webhook_verify_token_vault_id", `wa_meta_verify_${profile.id}`, "WABA_VERIFY_TOKEN"],
  }[kind];
  if (meta[settings[0]]) {
    const { data, error } = await db.rpc("get_internal_secret", { p_name: settings[1] });
    if (error) throw new Error("Profile credential lookup failed");
    return typeof data === "string" && data ? data : null;
  }
  const legacyAllowed = kind === "app_secret" || kind === "verify"
    ? meta.legacy_webhook_env === true : meta.use_legacy_env === true;
  return legacyAllowed ? Deno.env.get(settings[2]) || null : null;
}

export function profileReady(profile: any): boolean {
  const digits = (value: unknown) => String(value || "").replace(/\D/g, "");
  const expected = digits(profile?.expected_sender_number);
  return profile?.is_enabled === true && profile?.ready_state === "ready" &&
    expected.length >= 7 && expected === digits(profile?.observed_sender_number);
}
