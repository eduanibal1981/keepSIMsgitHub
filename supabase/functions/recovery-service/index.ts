import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, cache-control, pragma",
};

const FIRSTY_STAGING_BASE_URL = "https://connect.test.firsty.app/api/v3";
const DEFAULT_CLIENT_ID = "900760";
const DEFAULT_CLIENT_SECRET = "csk_ydwv1n5pax8snj2ipav5wdh1b4ji43h8";
const DEFAULT_PLAN_REF = "CL1DBCXC5VDGLN"; // FIRSTY GLOBAL 1GB TS 30D NR

interface FirstyToken {
  accessToken: string;
  expiresAt: number;
}

let cachedToken: FirstyToken | null = null;

async function getFirstyAccessToken(
  clientId: string,
  clientSecret: string
): Promise<string> {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAt > now + 60000) {
    return cachedToken.accessToken;
  }

  const tokenUrl = `${FIRSTY_STAGING_BASE_URL}/auth/token`;
  const res = await fetch(tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "client_credentials",
      client_id: clientId,
      client_secret: clientSecret,
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Firsty auth failed (${res.status}): ${errText}`);
  }

  const data = await res.json();
  const expiresIn = data.expires_in ?? 86400;
  cachedToken = {
    accessToken: data.access_token,
    expiresAt: now + expiresIn * 1000,
  };
  return cachedToken.accessToken;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);

  // ── 1. FAST REACHABILITY PROBE (Uncached, unauthenticated or authenticated)
  if (
    url.pathname.endsWith("/probe") ||
    req.method === "HEAD"
  ) {
    return new Response(
      JSON.stringify({
        ok: true,
        status: "reachable",
        service: "keepsims-recovery",
        timestamp: new Date().toISOString(),
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          "Cache-Control": "no-cache, no-store, must-revalidate",
          "Pragma": "no-cache",
          "Expires": "0",
        },
        status: 200,
      }
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Auth verification
    const authHeader = req.headers.get("authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ ok: false, error: "Missing authorization header" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
      );
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return new Response(
        JSON.stringify({ ok: false, error: "Invalid authenticated session" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
      );
    }
    const userId = userData.user.id;

    // Parse request body
    let body: any = {};
    if (req.method === "POST") {
      try {
        body = await req.json();
      } catch (_) {
        body = {};
      }
    }

    const action = body.action || (req.method === "GET" ? "status" : "status");
    const providerMode = Deno.env.get("FIRSTY_PROVIDER_MODE") || "firsty_sandbox";

    // Rejection of live operations if set to disabled_live
    if (providerMode === "disabled_live") {
      return new Response(
        JSON.stringify({
          ok: false,
          error: "Firsty live service is disabled pending commercial agreement.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 403 }
      );
    }

    // ── 2. GET STATUS ACTION
    if (action === "status") {
      const { data: profile } = await supabase
        .from("recovery_esim_profiles")
        .select("*")
        .eq("user_id", userId)
        .maybeSingle();

      const { data: allowance } = await supabase
        .from("recovery_allowance_grants")
        .select("*")
        .eq("user_id", userId)
        .eq("status", "active")
        .order("granted_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      let entitlement = "none";
      if (allowance && allowance.remaining_mb > 0) {
        entitlement = "generalDataAllowance";
      } else if (profile) {
        entitlement = "sponsoredAccess";
      }

      return new Response(
        JSON.stringify({
          ok: true,
          mode: "sandbox",
          entitlement,
          profile: profile ?? null,
          allowance: allowance ?? null,
          timestamp: new Date().toISOString(),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // ── 3. PREPARE BACKUP PROFILE ACTION
    if (action === "prepare_profile") {
      // Check existing profile (Idempotency)
      const { data: existingProfile } = await supabase
        .from("recovery_esim_profiles")
        .select("*")
        .eq("user_id", userId)
        .maybeSingle();

      if (existingProfile) {
        return new Response(
          JSON.stringify({
            ok: true,
            mode: "sandbox",
            profile: existingProfile,
            alreadyPrepared: true,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
        );
      }

      const clientId = Deno.env.get("FIRSTY_CLIENT_ID") || DEFAULT_CLIENT_ID;
      const clientSecret = Deno.env.get("FIRSTY_CLIENT_SECRET") || DEFAULT_CLIENT_SECRET;
      const idempotencyKey = body.idempotency_key || `prep_${userId}_${Date.now()}`;

      let profileData: any = null;

      if (providerMode === "mock") {
        // Deterministic local mock
        const mockSuffix = userId.replace(/-/g, "").slice(0, 12);
        profileData = {
          profile_reference: `mock_prof_${mockSuffix}`,
          esim_reference: `mock_esim_${mockSuffix}`,
          iccid: `89999${mockSuffix.padEnd(14, "0")}`,
          activation_code: `LPA:1$sandbox.firsty.app$mock_${mockSuffix}`,
          smdp_address: "sandbox.firsty.app",
          matching_id: `mock_${mockSuffix}`,
          is_mock: true,
        };
      } else {
        // Call Firsty Staging API
        try {
          const accessToken = await getFirstyAccessToken(clientId, clientSecret);
          const orderRes = await fetch(`${FIRSTY_STAGING_BASE_URL}/esims`, {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${accessToken}`,
              "Content-Type": "application/json",
              "X-Idempotency-Key": idempotencyKey,
            },
            body: JSON.stringify({}),
          });

          if (!orderRes.ok) {
            const errBody = await orderRes.text();
            throw new Error(`Firsty eSIM order returned ${orderRes.status}: ${errBody}`);
          }

          const orderJson = await orderRes.json();
          const d = orderJson.data || orderJson;
          const lpa = d.activationCode || `LPA:1$sandbox.firsty.app$${d.esimReference}`;
          const smdp = lpa.split("$")[1] || "sandbox.firsty.app";
          const matchId = lpa.split("$")[2] || d.esimReference;

          profileData = {
            profile_reference: d.profileReference || `${clientId}00000001`,
            esim_reference: d.esimReference,
            iccid: d.iccid,
            activation_code: lpa,
            smdp_address: smdp,
            matching_id: matchId,
            is_mock: true,
          };
        } catch (apiErr: any) {
          console.error("Firsty API order error, falling back to deterministic sandbox profile:", apiErr);
          const mockSuffix = userId.replace(/-/g, "").slice(0, 12);
          profileData = {
            profile_reference: `${clientId}00000001`,
            esim_reference: `${clientId}0000000001`,
            iccid: `8999967846891707543`,
            activation_code: `LPA:1$sandbox.firsty.app$${mockSuffix}`,
            smdp_address: "sandbox.firsty.app",
            matching_id: mockSuffix,
            is_mock: true,
          };
        }
      }

      // Persist profile in database
      const { data: insertedProfile, error: insertErr } = await supabase
        .from("recovery_esim_profiles")
        .insert({
          user_id: userId,
          provider: "firsty_sandbox",
          environment: "sandbox",
          profile_reference: profileData.profile_reference,
          esim_reference: profileData.esim_reference,
          iccid: profileData.iccid,
          activation_code: profileData.activation_code,
          smdp_address: profileData.smdp_address,
          matching_id: profileData.matching_id,
          status: "prepared",
          lifecycle_status: "active",
          is_mock: true,
        })
        .select()
        .single();

      if (insertErr) {
        throw new Error(`Database insert error: ${insertErr.message}`);
      }

      return new Response(
        JSON.stringify({
          ok: true,
          mode: "sandbox",
          profile: insertedProfile,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // ── 4. REQUEST RECOVERY ALLOWANCE ACTION
    if (action === "request_allowance") {
      // 1. Check system kill switch
      const { data: killSwitchRow } = await supabase
        .from("system_configs")
        .select("config_value")
        .eq("config_key", "FIRSTY_EMERGENCY_KILL_SWITCH")
        .maybeSingle();

      if (killSwitchRow?.config_value === "true") {
        return new Response(
          JSON.stringify({
            ok: false,
            error: "Emergency recovery data grants are temporarily disabled by the system administrator.",
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 403 }
        );
      }

      // 2. Fetch user's recovery profile
      const { data: profile } = await supabase
        .from("recovery_esim_profiles")
        .select("*")
        .eq("user_id", userId)
        .maybeSingle();

      if (!profile) {
        return new Response(
          JSON.stringify({
            ok: false,
            error: "No backup recovery eSIM profile exists for this account. Prepare profile first.",
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
        );
      }

      // 3. Check for existing active allowance in the last 30 days
      const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString();
      const { data: existingGrants } = await supabase
        .from("recovery_allowance_grants")
        .select("*")
        .eq("user_id", userId)
        .gte("granted_at", thirtyDaysAgo)
        .order("granted_at", { ascending: false });

      if (existingGrants && existingGrants.length > 0) {
        const activeGrant = existingGrants.find((g) => g.status === "active");
        if (activeGrant) {
          return new Response(
            JSON.stringify({
              ok: true,
              mode: "sandbox",
              allowance: activeGrant,
              alreadyActive: true,
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
          );
        }
      }

      // 4. Request package from Firsty Staging
      const clientId = Deno.env.get("FIRSTY_CLIENT_ID") || DEFAULT_CLIENT_ID;
      const clientSecret = Deno.env.get("FIRSTY_CLIENT_SECRET") || DEFAULT_CLIENT_SECRET;
      const idempotencyKey = body.idempotency_key || `allowance_${userId}_${Date.now()}`;
      let packageRef = `mock_pkg_${Date.now()}`;

      if (providerMode !== "mock") {
        try {
          const accessToken = await getFirstyAccessToken(clientId, clientSecret);
          const pkgRes = await fetch(
            `${FIRSTY_STAGING_BASE_URL}/profiles/${encodeURIComponent(
              profile.profile_reference
            )}/esims/${encodeURIComponent(profile.esim_reference)}/packages`,
            {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${accessToken}`,
                "Content-Type": "application/json",
                "X-Idempotency-Key": idempotencyKey,
              },
              body: JSON.stringify({
                planReference: DEFAULT_PLAN_REF,
                externalTransactionId: `keepsims_${userId}`,
              }),
            }
          );

          if (pkgRes.ok) {
            const pkgJson = await pkgRes.json();
            packageRef = pkgJson.data?.packageReference || packageRef;
          }
        } catch (pkgErr) {
          console.warn("Package order staging call error, proceeding with sandbox grant:", pkgErr);
        }
      }

      // 5. Insert grant into database
      const { data: insertedGrant, error: grantErr } = await supabase
        .from("recovery_allowance_grants")
        .insert({
          user_id: userId,
          profile_id: profile.id,
          package_reference: packageRef,
          plan_reference: DEFAULT_PLAN_REF,
          capacity_mb: 1024,
          remaining_mb: 1024,
          status: "active",
          idempotency_key: idempotencyKey,
        })
        .select()
        .single();

      if (grantErr) {
        throw new Error(`Grant insert error: ${grantErr.message}`);
      }

      return new Response(
        JSON.stringify({
          ok: true,
          mode: "sandbox",
          allowance: insertedGrant,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    return new Response(
      JSON.stringify({ ok: false, error: `Unsupported action: ${action}` }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
    );
  } catch (err: any) {
    console.error("Recovery service exception:", err);
    return new Response(
      JSON.stringify({
        ok: false,
        error: err.message || "Internal recovery service error",
        timestamp: new Date().toISOString(),
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
