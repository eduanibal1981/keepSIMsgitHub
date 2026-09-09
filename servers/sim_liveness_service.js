// ============================================================================
// sim_liveness_service.js — Carrier BSS Liveness & Activity Verification
// ============================================================================
// Performs pre-flight wholesale BSS lookup (DTOne & Zendit) before executing
// scheduled refills or deductions. Detects suspended, barred, or deactivated
// numbers early to prevent doomed top-up calls and financial discrepancies.
// ============================================================================

const DTONE_BASE_URL = process.env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';
const DTONE_API_KEY = process.env.DTONE_API_KEY;
const DTONE_API_SECRET = process.env.DTONE_API_SECRET;

const ZENDIT_BASE_URL = process.env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';
const ZENDIT_API_SECRET = process.env.ZENDIT_API_SECRET;

// Explicit deactivation keywords returned by carrier BSS
const EXPLICIT_DEACTIVATION_CODES = [
  'SUBSCRIBER_NOT_FOUND',
  'ACCOUNT_BARRED',
  'ACCOUNT_DEACTIVATED',
  'DEACTIVATED',
  'SUBSCRIBER_BARRED',
  'NUMBER_DISCONNECTED',
  'SUSPENDED',
  'INVALID_MSISDN_DEACTIVATED',
  'UNALLOCATED_NUMBER',
  'INACTIVE'
];

// In-memory cache for liveness checks (15-minute TTL)
const livenessCache = new Map();
const CACHE_TTL_MS = 15 * 60 * 1000;

function formatMsisdn(raw) {
  if (!raw) return '';
  let cleaned = String(raw).replace(/[\s\-\(\)]/g, '');
  if (!cleaned.startsWith('+')) {
    cleaned = `+${cleaned}`;
  }
  return cleaned;
}

function cleanOperatorName(rawName) {
  if (!rawName) return '';
  return String(rawName)
    .replace(/ PIN.*$/i, '')
    .replace(/ Direct.*$/i, '')
    .replace(/ Topup.*$/i, '')
    .replace(/ Oman.*$/i, '')
    .replace(/ Egypt.*$/i, '')
    .replace(/ Saudi.*$/i, '')
    .replace(/ UAE.*$/i, '')
    .replace(/ Company.*$/i, '')
    .replace(/ SAOC.*$/i, '')
    .trim();
}

function isExplicitlyDeactivated(errStr) {
  if (!errStr) return false;
  const upper = String(errStr).toUpperCase();
  return EXPLICIT_DEACTIVATION_CODES.some(code => upper.includes(code));
}

/**
 * Query DTOne BSS Mobile Number Lookup
 */
async function queryDTOne(formattedPhone, countryCode, timeoutMs = 8000) {
  if (!DTONE_API_KEY || !DTONE_API_SECRET) {
    return { success: false, reason: 'DTONE_CREDS_MISSING' };
  }

  const authHeader = `Basic ${Buffer.from(`${DTONE_API_KEY}:${DTONE_API_SECRET}`).toString('base64')}`;
  const headers = {
    Authorization: authHeader,
    Accept: 'application/json'
  };

  const testUrls = [
    `${DTONE_BASE_URL}/lookup/mobile-number/${encodeURIComponent(formattedPhone)}`,
    `${DTONE_BASE_URL}/lookup/mobile-number/${encodeURIComponent(formattedPhone.replace('+', ''))}`
  ];

  for (const url of testUrls) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetch(url, { headers, signal: controller.signal });
      const text = await res.text();
      clearTimeout(timer);

      if (res.ok) {
        let data = {};
        try { data = JSON.parse(text); } catch (_) { }

        if (Array.isArray(data)) {
          const activeOp = data.find(item => item.identified === true);
          if (activeOp) {
            return {
              success: true,
              active: true,
              operatorName: cleanOperatorName(activeOp.name || 'Carrier'),
              country: activeOp.country?.iso_code || countryCode
            };
          }
        } else if (data && typeof data === 'object') {
          if (data.identified === true) {
            const op = data.operator || data;
            const rawName = op.name || op.brand;
            if (rawName) {
              return {
                success: true,
                active: true,
                operatorName: cleanOperatorName(rawName),
                country: op.country?.iso_code || countryCode
              };
            }
          }
        }
      } else if (isExplicitlyDeactivated(text)) {
        return {
          success: true,
          active: false,
          reason: 'SUBSCRIBER_NOT_FOUND_OR_DEACTIVATED',
          raw: text
        };
      }
    } catch (err) {
      clearTimeout(timer);
      if (err.name !== 'AbortError') {
        console.warn(`[liveness] DTOne lookup error for ${formattedPhone}:`, err.message);
      }
    }
  }

  return { success: false, reason: 'INCONCLUSIVE' };
}

/**
 * Query Zendit BSS Lookup
 */
async function queryZendit(formattedPhone, countryCode, timeoutMs = 8000) {
  if (!ZENDIT_API_SECRET) {
    return { success: false, reason: 'ZENDIT_CREDS_MISSING' };
  }

  const headers = {
    Authorization: `Bearer ${ZENDIT_API_SECRET}`,
    'Content-Type': 'application/json',
    Accept: 'application/json'
  };

  const testUrls = [
    `${ZENDIT_BASE_URL}/topups/lookup?phoneNumber=${encodeURIComponent(formattedPhone)}`,
    `${ZENDIT_BASE_URL}/topups/lookup?recipientPhoneNumber=${encodeURIComponent(formattedPhone)}`
  ];

  for (const url of testUrls) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetch(url, { headers, signal: controller.signal });
      const text = await res.text();
      clearTimeout(timer);

      if (res.ok) {
        let data = {};
        try { data = JSON.parse(text); } catch (_) { }
        const rawName = data.name || data.brand || data.operator?.name || data.operator?.brand || (data.list && data.list[0]?.brand);
        const cCode = data.country || data.countryCode || (data.list && data.list[0]?.country) || countryCode;
        if (rawName) {
          return {
            success: true,
            active: true,
            operatorName: cleanOperatorName(String(rawName)),
            country: cCode ? String(cCode) : undefined
          };
        }
      } else if (isExplicitlyDeactivated(text)) {
        return {
          success: true,
          active: false,
          reason: 'DEACTIVATED_OR_UNALLOCATED',
          raw: text
        };
      }
    } catch (err) {
      clearTimeout(timer);
      if (err.name !== 'AbortError') {
        console.warn(`[liveness] Zendit lookup error for ${formattedPhone}:`, err.message);
      }
    }
  }

  return { success: false, reason: 'INCONCLUSIVE' };
}

/**
 * Validate subscriber liveness before executing scheduled refill
 *
 * @param {Object} params
 * @param {string} params.phoneNumber
 * @param {string} [params.countryCode]
 * @param {boolean} [params.skipCache=false]
 * @param {number} [params.timeoutMs=8000]
 * @returns {Promise<{
 *   ok: boolean,
 *   status: 'active' | 'inactive' | 'inconclusive',
 *   reason: string | null,
 *   operatorName: string | null,
 *   message: string
 * }>}
 */
async function validateSubscriberLiveness({ phoneNumber, countryCode, skipCache = false, timeoutMs = 8000 }) {
  const cleanPhone = formatMsisdn(phoneNumber);
  if (!cleanPhone || cleanPhone.length < 7) {
    return {
      ok: false,
      status: 'inactive',
      reason: 'INVALID_PHONE_NUMBER',
      operatorName: null,
      message: 'Invalid phone number format.'
    };
  }

  // Check cache
  const cacheKey = `live_${cleanPhone}`;
  if (!skipCache) {
    const cached = livenessCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.result;
    }
  }

  // 1. Try DTOne lookup first
  const dtoneRes = await queryDTOne(cleanPhone, countryCode, timeoutMs);
  if (dtoneRes.success) {
    if (dtoneRes.active === false) {
      const result = {
        ok: false,
        status: 'inactive',
        reason: dtoneRes.reason || 'CARRIER_DEACTIVATED',
        operatorName: null,
        message: 'Carrier BSS reports subscriber line inactive, barred, or disconnected.'
      };
      livenessCache.set(cacheKey, { result, expiresAt: Date.now() + CACHE_TTL_MS });
      return result;
    }

    if (dtoneRes.active === true) {
      const result = {
        ok: true,
        status: 'active',
        reason: null,
        operatorName: dtoneRes.operatorName || null,
        message: 'Subscriber confirmed active on carrier network.'
      };
      livenessCache.set(cacheKey, { result, expiresAt: Date.now() + CACHE_TTL_MS });
      return result;
    }
  }

  // 2. Fall back to Zendit lookup
  const zenditRes = await queryZendit(cleanPhone, countryCode, timeoutMs);
  if (zenditRes.success) {
    if (zenditRes.active === false) {
      const result = {
        ok: false,
        status: 'inactive',
        reason: zenditRes.reason || 'CARRIER_DEACTIVATED',
        operatorName: null,
        message: 'Carrier BSS reports subscriber line inactive, barred, or disconnected.'
      };
      livenessCache.set(cacheKey, { result, expiresAt: Date.now() + CACHE_TTL_MS });
      return result;
    }

    if (zenditRes.active === true) {
      const result = {
        ok: true,
        status: 'active',
        reason: null,
        operatorName: zenditRes.operatorName || null,
        message: 'Subscriber confirmed active on carrier network.'
      };
      livenessCache.set(cacheKey, { result, expiresAt: Date.now() + CACHE_TTL_MS });
      return result;
    }
  }

  // 3. Inconclusive: Not all small regional carriers support zero-cost BSS lookup.
  // We do NOT block the refill if the carrier API is inconclusive; only explicit deactivation blocks it.
  const inconclusiveResult = {
    ok: true,
    status: 'inconclusive',
    reason: null,
    operatorName: null,
    message: 'Carrier lookup inconclusive; line may be active.'
  };
  livenessCache.set(cacheKey, { result: inconclusiveResult, expiresAt: Date.now() + (5 * 60 * 1000) });
  return inconclusiveResult;
}

module.exports = {
  validateSubscriberLiveness,
  formatMsisdn,
  isExplicitlyDeactivated
};
