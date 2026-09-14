'use strict';

/**
 * Firsty Sandbox Provider Adapter
 * 
 * Supports:
 * - OAuth2 Client Credentials authentication
 * - Sandbox eSIM ordering (returns LPA string)
 * - Package ordering (1 GB recovery packages)
 * - Usage polling & status queries
 * - Deterministic offline mock mode
 */

const FIRSTY_STAGING_BASE_URL = 'https://connect.test.firsty.app/api/v3';
const DEFAULT_PLAN_REF = 'CL1DBCXC5VDGLN'; // FIRSTY GLOBAL 1GB TS 30D NR

let tokenCache = null;

async function getAccessToken({
  baseUrl = FIRSTY_STAGING_BASE_URL,
  clientId,
  clientSecret,
  fetchImpl = fetch,
}) {
  const now = Date.now();
  if (tokenCache && tokenCache.expiresAt > now + 60000) {
    return tokenCache.accessToken;
  }

  const tokenUrl = `${baseUrl.replace(/\/$/, '')}/auth/token`;
  const res = await fetchImpl(tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: clientId,
      client_secret: clientSecret,
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Firsty auth failed (${res.status}): ${errText}`);
  }

  const data = await res.json();
  const expiresIn = data.expires_in || 86400;
  tokenCache = {
    accessToken: data.access_token,
    expiresAt: now + expiresIn * 1000,
  };
  return tokenCache.accessToken;
}

async function orderEsim({
  baseUrl = FIRSTY_STAGING_BASE_URL,
  accessToken,
  idempotencyKey,
  fetchImpl = fetch,
  mock = false,
}) {
  if (mock) {
    const mockRef = `mock_${Date.now()}`;
    return {
      profileReference: `mock_prof_${mockRef}`,
      esimReference: `mock_esim_${mockRef}`,
      iccid: '8999967846891707543',
      activationCode: `LPA:1$sandbox.firsty.app$${mockRef}`,
      smdpAddress: 'sandbox.firsty.app',
      matchingId: mockRef,
      isMock: true,
      status: 'released',
      lifecycleStatus: 'active',
    };
  }

  const headers = {
    'Authorization': `Bearer ${accessToken}`,
    'Content-Type': 'application/json',
  };
  if (idempotencyKey) {
    headers['X-Idempotency-Key'] = idempotencyKey;
  }

  const res = await fetchImpl(`${baseUrl.replace(/\/$/, '')}/esims`, {
    method: 'POST',
    headers,
    body: JSON.stringify({}),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Firsty orderEsim returned status ${res.status}: ${errText}`);
  }

  const json = await res.json();
  const data = json.data || json;
  const lpa = data.activationCode || `LPA:1$sandbox.firsty.app$${data.esimReference}`;
  const parts = lpa.split('$');

  return {
    profileReference: data.profileReference,
    esimReference: data.esimReference,
    iccid: data.iccid,
    activationCode: lpa,
    smdpAddress: parts[1] || 'sandbox.firsty.app',
    matchingId: parts[2] || data.esimReference,
    status: data.status || 'released',
    lifecycleStatus: data.lifecycleStatus || 'active',
    isMock: true,
  };
}

async function orderPackage({
  baseUrl = FIRSTY_STAGING_BASE_URL,
  accessToken,
  profileReference,
  esimReference,
  planReference = DEFAULT_PLAN_REF,
  externalId,
  idempotencyKey,
  fetchImpl = fetch,
  mock = false,
}) {
  if (mock) {
    return {
      packageReference: `mock_pkg_${Date.now()}`,
      planReference,
      status: 'active',
      capacityMb: 1024,
      remainingMb: 1024,
      isMock: true,
    };
  }

  const url = `${baseUrl.replace(/\/$/, '')}/profiles/${encodeURIComponent(profileReference)}/esims/${encodeURIComponent(esimReference)}/packages`;
  const headers = {
    'Authorization': `Bearer ${accessToken}`,
    'Content-Type': 'application/json',
  };
  if (idempotencyKey) {
    headers['X-Idempotency-Key'] = idempotencyKey;
  }

  const body = {
    planReference,
    ...(externalId ? { externalTransactionId: externalId } : {}),
  };

  const res = await fetchImpl(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Firsty orderPackage returned status ${res.status}: ${errText}`);
  }

  const json = await res.json();
  const data = json.data || json;

  return {
    packageReference: data.packageReference,
    planReference: data.planReference || planReference,
    status: data.status || 'active',
    capacityMb: data.capacityMb || 1024,
    remainingMb: data.capacityMb || 1024,
    isMock: true,
  };
}

async function getUsage({
  baseUrl = FIRSTY_STAGING_BASE_URL,
  accessToken,
  profileReference,
  esimReference,
  fetchImpl = fetch,
  mock = false,
}) {
  if (mock) {
    return {
      totalMb: 1024,
      remainingMb: 1024,
      consumedMb: 0,
      isMock: true,
    };
  }

  const url = `${baseUrl.replace(/\/$/, '')}/profiles/${encodeURIComponent(profileReference)}/esims/${encodeURIComponent(esimReference)}/usage`;
  const res = await fetchImpl(url, {
    method: 'GET',
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Firsty getUsage returned status ${res.status}: ${errText}`);
  }

  const json = await res.json();
  return json.data || json;
}

module.exports = {
  FIRSTY_STAGING_BASE_URL,
  DEFAULT_PLAN_REF,
  getAccessToken,
  orderEsim,
  orderPackage,
  getUsage,
};
