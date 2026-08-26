const zenditBaseUrl = process.env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

function normalizeZenditProduct(o) {
  const isRange = o.priceType === 'RANGE';
  const divisor = o.send?.currencyDivisor || 100;
  const ccy = o.send?.currency || 'USD';

  let benefitSummary = o.shortNotes || o.notes || o.name || null;
  if (!benefitSummary) {
    if (o.dataGB && o.dataGB > 0) {
      const dur = o.durationDays ? ` • ${o.durationDays} Days` : '';
      benefitSummary = `${o.dataGB} GB Data${dur}`;
    } else if (isRange) {
      const minVal = (o.send?.min || 0) / divisor;
      const maxVal = (o.send?.max || 0) / divisor;
      benefitSummary = `${minVal}-${maxVal} ${ccy} Custom Airtime`;
    } else if (o.send?.fixed != null) {
      const fixedVal = o.send.fixed / divisor;
      const formatted = Number.isInteger(fixedVal) ? fixedVal : parseFloat(fixedVal.toFixed(2));
      benefitSummary = `${formatted} ${ccy} Airtime Balance`;
    }
  }

  return {
    ...o,
    name: o.name || benefitSummary || o.offerId,
    benefitSummary: benefitSummary || `${o.offerId} Airtime`,
  };
}

async function fetchCatalog({ baseUrl = zenditBaseUrl, apiSecret, countryCode, carrierCode, fetchImpl = fetch }) {
  const all = [];
  let pageOffset = 0;
  let catalogTotal = Infinity;
  while (pageOffset < catalogTotal && pageOffset < 500) {
    const url = `${baseUrl}/topups/offers?country=${encodeURIComponent(countryCode)}&brand=${encodeURIComponent(carrierCode)}&_limit=100&_offset=${pageOffset}`;
    const res = await fetchImpl(url, { headers: { Authorization: `Bearer ${apiSecret}` } });
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Zendit Offers API returned status ${res.status}: ${errText}`);
    }
    const data = await res.json();
    catalogTotal = data.total || 0;
    all.push(...(data.list || []));
    pageOffset += 100;
  }

  return all
    .filter(o => o.enabled && o.productType === 'TOPUP' && (o.subTypes || []).includes('Mobile Top Up'))
    .map(normalizeZenditProduct);
}

async function purchase({ baseUrl = zenditBaseUrl, apiSecret, execution, recipientPhone, offerId, offerValue, externalId, fetchImpl = fetch }) {
  const transactionId = externalId || `z_${execution.id}`;
  const purchaseBody = {
    transactionId,
    recipientPhoneNumber: recipientPhone,
    offerId,
  };
  if (offerValue != null) {
    purchaseBody.value = (typeof offerValue === 'object' && offerValue !== null)
      ? offerValue
      : { type: 'ZEND', value: Math.round(Number(offerValue)) };
  }

  const purchaseResponse = await fetchImpl(`${baseUrl}/topups/purchases`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiSecret}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(purchaseBody)
  });

  let purchaseData;
  if (purchaseResponse.ok) {
    purchaseData = await purchaseResponse.json();
  } else {
    const errText = await purchaseResponse.text();
    // Adopt-on-retry
    const existingResponse = await fetchImpl(`${baseUrl}/topups/purchases/${transactionId}`, {
      headers: { 'Authorization': `Bearer ${apiSecret}` }
    });
    if (existingResponse.ok) {
      console.log(`[Zendit] Purchase ${transactionId} already exists from an earlier attempt. Adopting it.`);
      purchaseData = await existingResponse.json();
    } else {
      throw new Error(`Zendit Purchase API Error: ${purchaseResponse.status} - ${errText}`);
    }
  }

  return {
    transactionId: purchaseData.transactionId || transactionId,
    status: purchaseData.status || 'PENDING',
    raw: purchaseData
  };
}

async function pollStatus({ baseUrl = zenditBaseUrl, apiSecret, transactionId, maxPolls = 12, pollDelayMs = 2500, fetchImpl = fetch }) {
  let pollCount = 0;
  let currentStatus = 'PENDING';
  let purchaseData = null;

  while (['ACCEPTED', 'PENDING', 'AUTHORIZED', 'IN_PROGRESS'].includes(currentStatus) && pollCount < maxPolls) {
    await new Promise(resolve => setTimeout(resolve, pollDelayMs));
    try {
      const checkResponse = await fetchImpl(`${baseUrl}/topups/purchases/${transactionId}`, {
        headers: {
          'Authorization': `Bearer ${apiSecret}`,
          'Content-Type': 'application/json'
        }
      });
      if (checkResponse.ok) {
        purchaseData = await checkResponse.json();
        currentStatus = purchaseData.status || currentStatus;
      }
    } catch (err) {
      console.log(`[Zendit Polling Warning]: ${err.message}`);
    }
    pollCount++;
  }

  const isSuccess = ['SUCCESS', 'COMPLETED', 'DONE'].includes(currentStatus);
  const isFailed = ['FAILED', 'DECLINED', 'REJECTED', 'CANCELLED'].includes(currentStatus);

  return {
    status: currentStatus,
    isSuccess,
    isFailed,
    errorMsg: isFailed ? (purchaseData?.error?.message || `Transaction failed with status: ${currentStatus}`) : null,
    raw: purchaseData
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Zendit eSIM Methods
// ─────────────────────────────────────────────────────────────────────────────

const ZENDIT_SPEED_TIER_MAP = {
  'Standard': 'fixed',
  'standard': 'fixed',
  'fixed': 'fixed',
  'Fast': 'lite',
  'fast': 'lite',
  'lite': 'lite',
  'Faster': 'essential',
  'faster': 'essential',
  'essential': 'essential',
  'Fastest': 'plus',
  'fastest': 'plus',
  'plus': 'plus',
  'Premium': 'plus',
  'premium': 'plus',
  'Long Duration': 'long_duration',
  'long_duration': 'long_duration',
};

function normalizeZenditEsimOffer(o) {
  if (!o || !o.offerId) return null;

  const rawCountries = [];
  if (o.country && typeof o.country === 'string') {
    rawCountries.push(o.country.trim().toUpperCase());
  }

  const roamingCountries = [];
  if (Array.isArray(o.roaming)) {
    for (const r of o.roaming) {
      if (r && r.country && typeof r.country === 'string') {
        const iso = r.country.trim().toUpperCase();
        roamingCountries.push(iso);
        rawCountries.push(iso);
      }
    }
  }

  const allCountries = Array.from(new Set(rawCountries.filter(Boolean)));
  const uniqueRoaming = Array.from(new Set(roamingCountries.filter(Boolean)));

  const isUnlimited = o.dataUnlimited === true || o.dataGB === 0 || o.dataAmount === -1;
  let dataAmountMb = 0;
  if (!isUnlimited) {
    if (typeof o.dataGB === 'number' && o.dataGB > 0) {
      dataAmountMb = Math.round(o.dataGB * 1024);
    } else if (typeof o.dataMB === 'number' && o.dataMB > 0) {
      dataAmountMb = Math.round(o.dataMB);
    } else if (typeof o.dataAmount === 'number' && o.dataAmount > 0) {
      dataAmountMb = Math.round(o.dataAmount);
    }
  }

  const divisor = o.cost?.currencyDivisor || 100;
  const rawCost = o.cost?.fixed != null ? o.cost.fixed : 0;
  const wholesaleCostUsd = parseFloat((rawCost / divisor).toFixed(4));

  const subTypes = Array.isArray(o.subTypes) ? o.subTypes : [];
  const primarySubType = subTypes.length > 0 ? String(subTypes[0]).trim() : null;
  const speedTier = primarySubType ? (ZENDIT_SPEED_TIER_MAP[primarySubType] || null) : null;

  const regions = Array.isArray(o.regions) ? o.regions : [];
  const region = regions.length > 0 ? String(regions[0]) : null;

  const description = o.shortNotes || o.notes || o.name || (isUnlimited ? `${o.durationDays || 0} Days Unlimited Data` : `${o.dataGB || 0}GB ${o.durationDays || 0} Days`);

  return {
    provider: 'zendit',
    bundle_name: String(o.offerId).trim(),
    description: String(description).trim(),
    countries: allCountries,
    roaming_enabled: uniqueRoaming,
    data_amount_mb: dataAmountMb,
    duration_days: parseInt(o.durationDays) || 0,
    wholesale_price_usd: wholesaleCostUsd,
    image_url: null,
    is_unlimited: isUnlimited,
    bundle_group: primarySubType || 'Standard',
    speed_tier: speedTier,
    region: region,
    country_count: allCountries.length,
    is_active: o.enabled !== false,
    updated_at: new Date().toISOString(),
  };
}

async function fetchEsimCatalog({
  baseUrl = zenditBaseUrl,
  apiSecret,
  countryCode,
  limit = 100,
  maxPages = 100,
  fetchImpl = fetch,
}) {
  if (!apiSecret) {
    throw new Error('ZENDIT_API_SECRET is required to fetch Zendit eSIM catalog');
  }

  const allOffers = [];
  let offset = 0;
  let total = Infinity;
  let page = 0;

  while (offset < total && page < maxPages) {
    let url = `${baseUrl}/esim/offers?_limit=${limit}&_offset=${offset}`;
    if (countryCode) {
      url += `&country=${encodeURIComponent(countryCode)}`;
    }

    const res = await fetchImpl(url, {
      headers: {
        'Authorization': `Bearer ${apiSecret}`,
        'Accept': 'application/json',
      },
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Zendit eSIM Offers API returned HTTP ${res.status}: ${errText}`);
    }

    const json = await res.json();
    total = typeof json.total === 'number' ? json.total : (json.list?.length || 0);
    const list = json.list || [];
    allOffers.push(...list);

    if (list.length === 0) break;
    offset += list.length;
    page++;
  }

  return {
    offers: allOffers,
    complete: offset >= total || allOffers.length >= total,
  };
}

async function purchaseEsim({
  baseUrl = zenditBaseUrl,
  apiSecret,
  offerId,
  transactionId,
  iccid,
  fetchImpl = fetch,
}) {
  if (!apiSecret) {
    throw new Error('ZENDIT_API_SECRET is required to purchase Zendit eSIM');
  }

  const purchaseBody = {
    offerId,
    transactionId,
    ...(iccid ? { iccid } : {}),
  };

  const res = await fetchImpl(`${baseUrl}/esim/purchases`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiSecret}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify(purchaseBody),
  });

  let data;
  if (res.ok) {
    data = await res.json();
  } else {
    const errText = await res.text();
    // Adopt-on-retry check
    const checkRes = await fetchImpl(`${baseUrl}/esim/purchases/${transactionId}`, {
      headers: {
        'Authorization': `Bearer ${apiSecret}`,
        'Accept': 'application/json',
      },
    });
    if (checkRes.ok) {
      console.log(`[Zendit eSIM] Purchase ${transactionId} already exists from an earlier attempt. Adopting it.`);
      data = await checkRes.json();
    } else {
      throw new Error(`Zendit eSIM Purchase API Error: ${res.status} - ${errText}`);
    }
  }

  return {
    transactionId: data.transactionId || transactionId,
    status: data.status || 'PENDING',
    raw: data,
  };
}

async function pollEsimPurchaseStatus({
  baseUrl = zenditBaseUrl,
  apiSecret,
  transactionId,
  maxPolls = 15,
  pollDelayMs = 2500,
  fetchImpl = fetch,
}) {
  let pollCount = 0;
  let currentStatus = 'PENDING';
  let purchaseData = null;

  while (['ACCEPTED', 'PENDING', 'AUTHORIZED', 'IN_PROGRESS'].includes(currentStatus) && pollCount < maxPolls) {
    await new Promise(resolve => setTimeout(resolve, pollDelayMs));
    try {
      const res = await fetchImpl(`${baseUrl}/esim/purchases/${transactionId}`, {
        headers: {
          'Authorization': `Bearer ${apiSecret}`,
          'Accept': 'application/json',
        },
      });
      if (res.ok) {
        purchaseData = await res.json();
        currentStatus = purchaseData.status || currentStatus;
      }
    } catch (err) {
      console.log(`[Zendit eSIM Polling Warning]: ${err.message}`);
    }
    pollCount++;
  }

  const isSuccess = ['SUCCESS', 'COMPLETED', 'DONE'].includes(currentStatus);
  const isFailed = ['FAILED', 'DECLINED', 'REJECTED', 'CANCELLED'].includes(currentStatus);

  return {
    status: currentStatus,
    isSuccess,
    isFailed,
    confirmation: purchaseData?.confirmation || null,
    errorMsg: isFailed ? (purchaseData?.error?.message || `Transaction failed with status: ${currentStatus}`) : null,
    raw: purchaseData,
  };
}

async function getEsimPlans({
  baseUrl = zenditBaseUrl,
  apiSecret,
  iccid,
  fetchImpl = fetch,
}) {
  if (!apiSecret || !iccid) return null;

  const res = await fetchImpl(`${baseUrl}/esim/${encodeURIComponent(iccid)}/plans`, {
    headers: {
      'Authorization': `Bearer ${apiSecret}`,
      'Accept': 'application/json',
    },
  });

  if (!res.ok) return null;
  return await res.json();
}

module.exports = {
  fetchCatalog,
  normalizeZenditProduct,
  purchase,
  pollStatus,
  // eSIM exports
  ZENDIT_SPEED_TIER_MAP,
  normalizeZenditEsimOffer,
  fetchEsimCatalog,
  purchaseEsim,
  pollEsimPurchaseStatus,
  getEsimPlans,
};
