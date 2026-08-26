const esimAccessBaseUrl = process.env.ESIM_ACCESS_BASE_URL || 'https://api.esimaccess.com/api/v1/open';

const ESIMACCESS_SPEED_TIER_MAP = {
  'fixed': 'fixed',
  'Fixed': 'fixed',
  '3G/4G': 'fixed',
  '4G': 'fixed',
  '4G/5G': 'plus',
  '5G': 'plus',
  'lite': 'lite',
  'Lite': 'lite',
  'essential': 'essential',
  'Essential': 'essential',
  'plus': 'plus',
  'Plus': 'plus',
  'Standard': 'fixed',
  'standard': 'fixed',
  'Fast': 'lite',
  'fast': 'lite',
  'Faster': 'essential',
  'faster': 'essential',
  'Fastest': 'plus',
  'fastest': 'plus',
  'long_duration': 'long_duration',
  'Long Duration': 'long_duration',
};

function extractIsoCountries(pkg) {
  if (!pkg) return [];

  const rawList = [];

  // 1. location field (string: "SI" or "US,CA" or array)
  if (typeof pkg.location === 'string') {
    pkg.location.split(',').forEach(c => rawList.push(c.trim()));
  } else if (Array.isArray(pkg.location)) {
    pkg.location.forEach(c => rawList.push(String(c).trim()));
  }

  // 2. locationCode field
  if (typeof pkg.locationCode === 'string') {
    pkg.locationCode.split(',').forEach(c => rawList.push(c.trim()));
  } else if (Array.isArray(pkg.locationCode)) {
    pkg.locationCode.forEach(c => rawList.push(String(c).trim()));
  }

  // 3. locationCodeList
  if (Array.isArray(pkg.locationCodeList)) {
    pkg.locationCodeList.forEach(c => rawList.push(String(c).trim()));
  }

  // 4. locationList
  if (Array.isArray(pkg.locationList)) {
    for (const loc of pkg.locationList) {
      if (typeof loc === 'string') rawList.push(loc.trim());
      else if (loc && loc.code) rawList.push(String(loc.code).trim());
      else if (loc && loc.locationCode) rawList.push(String(loc.locationCode).trim());
    }
  }

  // 5. locationNetworkList
  if (Array.isArray(pkg.locationNetworkList)) {
    for (const item of pkg.locationNetworkList) {
      if (item && item.locationCode) rawList.push(String(item.locationCode).trim());
      else if (item && item.locationName && item.locationName.length === 2) {
        rawList.push(String(item.locationName).trim());
      }
    }
  }

  // 6. coveredCountries
  if (Array.isArray(pkg.coveredCountries)) {
    pkg.coveredCountries.forEach(c => rawList.push(String(c).trim()));
  }

  // 7. slug parsing fallback (e.g. "SI_5_30" or "US_CA_10_30")
  if (rawList.length === 0 && typeof pkg.slug === 'string') {
    const parts = pkg.slug.split('_');
    if (parts[0] && parts[0].length === 2 && /^[A-Za-z]{2}$/.test(parts[0])) {
      rawList.push(parts[0]);
    }
  }

  return Array.from(
    new Set(
      rawList
        .map(c => c.toUpperCase())
        .filter(c => /^[A-Z]{2}$/.test(c))
    )
  );
}

function normalizeEsimAccessOffer(pkg) {
  if (!pkg || (!pkg.packageCode && !pkg.slug)) return null;

  const bundleName = String(pkg.packageCode || pkg.slug).trim();
  const allCountries = extractIsoCountries(pkg);
  const isMultiCountry = allCountries.length > 1;
  const roamingCountries = isMultiCountry ? allCountries : [];

  const textToScan = `${pkg.name || ''} ${pkg.description || ''}`;
  const isDaily = /daily|\/day|fup|daypass/i.test(textToScan) ||
    pkg.dataType === 'DAILY' || pkg.packageType === 'DAILY';

  // Data calculation: volume in bytes (e.g. 5368709120 bytes -> 5120 MB)
  const isUnlimited = isDaily ||
    pkg.isUnlimited === true ||
    pkg.volume <= 0 ||
    pkg.dataGB === 0 ||
    /unlimited/i.test(textToScan);

  const bundleGroup = isDaily ? 'DayPass' : 'Fixed Bundle';

  let dataAmountMb = 0;
  if (typeof pkg.volume === 'number' && pkg.volume > 0) {
    dataAmountMb = Math.round(pkg.volume / (1024 * 1024));
  } else if (typeof pkg.dataMB === 'number' && pkg.dataMB > 0) {
    dataAmountMb = Math.round(pkg.dataMB);
  } else if (typeof pkg.dataGB === 'number' && pkg.dataGB > 0) {
    dataAmountMb = Math.round(pkg.dataGB * 1024);
  }

  // Duration in days
  let durationDays = 0;
  const rawDuration = parseInt(pkg.duration) || 0;
  const unit = String(pkg.durationUnit || 'DAY').toUpperCase();
  if (unit === 'HOUR' || unit === 'HOURS') {
    durationDays = Math.max(1, Math.ceil(rawDuration / 24));
  } else if (unit === 'MONTH' || unit === 'MONTHS') {
    durationDays = rawDuration * 30;
  } else {
    durationDays = rawDuration;
  }

  // Price conversion: eSIM Access uses price x 10,000 (e.g. 112500 -> 11.25 USD)
  const divisor = pkg.currencyDivisor || 10000.0;
  const rawPrice = typeof pkg.price === 'number' ? pkg.price : (parseFloat(pkg.price) || 0);
  const wholesalePriceUsd = parseFloat((rawPrice / divisor).toFixed(4));

  // Speed tier mapping
  let speedTier = 'fixed';
  if (isDaily) {
    const fupMatch = textToScan.match(/(?:fup\s*|daily\s*fup\s*)([0-9]+(?:\.[0-9]+)?\s*(?:mbps|kbps|m|k))/i) ||
      (pkg.fupPolicy && String(pkg.fupPolicy).match(/([0-9]+(?:\.[0-9]+)?\s*(?:mbps|kbps|m|k))/i)) ||
      (pkg.fup && String(pkg.fup).match(/([0-9]+(?:\.[0-9]+)?\s*(?:mbps|kbps|m|k))/i));

    if (fupMatch && fupMatch[1]) {
      const rawRate = fupMatch[1].trim();
      if (/1\s*mbps|1m/i.test(rawRate)) {
        speedTier = 'high-1 Mbps';
      } else if (/128\s*kbps/i.test(rawRate)) {
        speedTier = 'high-128 kbps';
      } else if (/512\s*kbps/i.test(rawRate)) {
        speedTier = 'high-512 kbps';
      } else if (/500\s*kbps/i.test(rawRate)) {
        speedTier = 'high-500 kbps';
      } else if (/384\s*kbps/i.test(rawRate)) {
        speedTier = 'high-384 kbps';
      } else {
        speedTier = `high-${rawRate}`;
      }
    } else if (/1\s*mbps/i.test(textToScan)) {
      speedTier = 'high-1 Mbps';
    } else if (/128\s*kbps/i.test(textToScan)) {
      speedTier = 'high-128 kbps';
    } else if (/512\s*kbps/i.test(textToScan)) {
      speedTier = 'high-512 kbps';
    } else {
      // Default DayPass FUP policy is 384 Kbps in eSIM Access
      speedTier = 'high-384 kbps';
    }
  } else {
    speedTier = 'fixed';
  }

  // Region detection
  let region = null;
  if (pkg.region) {
    region = String(pkg.region).trim();
  } else if (/Global|Worldwide/i.test(pkg.name || '')) {
    region = 'Global';
  } else if (/Europe|EU/i.test(pkg.name || '')) {
    region = 'Europe';
  } else if (/Asia/i.test(pkg.name || '')) {
    region = 'Asia';
  } else if (/North America/i.test(pkg.name || '')) {
    region = 'North America';
  } else if (/Latin America|LATAM/i.test(pkg.name || '')) {
    region = 'Latin America';
  } else if (/Middle East|GCC|MENA/i.test(pkg.name || '')) {
    region = 'Middle East';
  } else if (/Africa/i.test(pkg.name || '')) {
    region = 'Africa';
  } else if (allCountries.length > 5) {
    region = 'Regional';
  }

  const description = String(pkg.description || pkg.name || (isDaily ? `${durationDays} DayPass Daily Unlimited` : `${Math.round(dataAmountMb / 1024)}GB ${durationDays} Days`)).trim();

  const isActive = pkg.status === 'ACTIVE' ||
    pkg.status === 'NORMAL' ||
    pkg.enabled !== false ||
    pkg.activeType !== 0;

  return {
    provider: 'esimaccess',
    bundle_name: bundleName,
    description: description,
    countries: allCountries,
    roaming_enabled: roamingCountries,
    data_amount_mb: dataAmountMb,
    duration_days: durationDays,
    wholesale_price_usd: wholesalePriceUsd,
    image_url: pkg.imageUrl || pkg.locationLogo || null,
    is_unlimited: isUnlimited,
    bundle_group: bundleGroup,
    speed_tier: speedTier,
    region: region,
    country_count: allCountries.length,
    is_active: isActive,
    updated_at: new Date().toISOString(),
  };
}

async function fetchEsimCatalog({
  baseUrl = esimAccessBaseUrl,
  accessCode,
  secretKey,
  locationCode,
  packageCode,
  fetchImpl = fetch,
}) {
  if (!accessCode) {
    throw new Error('ESIM_ACCESS_ACCESS_CODE is required to fetch eSIM Access catalog');
  }

  const headers = {
    'RT-AccessCode': accessCode,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  if (secretKey) {
    headers['secretKey'] = secretKey;
  }

  const body = {};
  if (locationCode) body.locationCode = locationCode;
  if (packageCode) body.packageCode = packageCode;

  const res = await fetchImpl(`${baseUrl}/package/list`, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`eSIM Access Package List API returned HTTP ${res.status}: ${errText}`);
  }

  const json = await res.json();
  if (json.success === false && json.errorCode && json.errorCode !== '0') {
    throw new Error(`eSIM Access Package List API error [${json.errorCode}]: ${json.errorMsg || json.errorMessage}`);
  }

  const packageList = (json.obj && Array.isArray(json.obj.packageList)) ? json.obj.packageList : [];

  return {
    offers: packageList,
    complete: true,
    raw: json,
  };
}

async function purchaseEsim({
  baseUrl = esimAccessBaseUrl,
  accessCode,
  secretKey,
  packageCode,
  quantity = 1,
  price,
  transactionId,
  fetchImpl = fetch,
}) {
  if (!accessCode) {
    throw new Error('ESIM_ACCESS_ACCESS_CODE is required to purchase eSIM Access eSIM');
  }
  if (!packageCode) {
    throw new Error('packageCode is required to purchase eSIM Access eSIM');
  }

  const txId = transactionId || `ea_${Date.now()}`;
  const priceIn10k = typeof price === 'number' ? Math.round(price * 10000) : undefined;
  const count = parseInt(quantity) || 1;

  const packageInfo = {
    packageCode,
    count,
  };
  if (priceIn10k !== undefined) {
    packageInfo.price = priceIn10k;
  }

  const purchaseBody = {
    transactionId: txId,
    amount: priceIn10k !== undefined ? priceIn10k * count : undefined,
    packageInfoList: [packageInfo],
  };

  const headers = {
    'RT-AccessCode': accessCode,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  if (secretKey) {
    headers['secretKey'] = secretKey;
  }

  const res = await fetchImpl(`${baseUrl}/esim/order`, {
    method: 'POST',
    headers,
    body: JSON.stringify(purchaseBody),
  });

  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch (_) {
    json = null;
  }

  if (!res.ok || (json && json.success === false && json.errorCode && json.errorCode !== '0')) {
    // Attempt adopt-on-retry check via query if duplicate transaction
    try {
      const checkRes = await fetchImpl(`${baseUrl}/esim/query`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ pager: { pageNum: 1, pageSize: 10 } }),
      });
      if (checkRes.ok) {
        const checkJson = await checkRes.json();
        const existing = (checkJson.obj?.esimList || []).find(e => e.transactionId === txId);
        if (existing) {
          console.log(`[eSIM Access] Order ${txId} already exists (orderNo: ${existing.orderNo}). Adopting it.`);
          return {
            orderNo: existing.orderNo,
            transactionId: txId,
            status: 'ACCEPTED',
            raw: checkJson,
          };
        }
      }
    } catch (_) { /* ignore fallback error */ }

    const errCode = json?.errorCode || res.status;
    const errMsg = json?.errorMsg || json?.errorMessage || text;
    throw new Error(`eSIM Access Order API Error [${errCode}]: ${errMsg}`);
  }

  const orderNo = json?.obj?.orderNo || null;

  return {
    orderNo,
    transactionId: txId,
    status: 'ACCEPTED',
    raw: json,
  };
}

async function pollEsimOrderStatus({
  baseUrl = esimAccessBaseUrl,
  accessCode,
  secretKey,
  orderNo,
  transactionId,
  maxPolls = 15,
  pollDelayMs = 2500,
  fetchImpl = fetch,
}) {
  let pollCount = 0;
  let esimList = [];
  let isSuccess = false;
  let isFailed = false;
  let lastData = null;

  const headers = {
    'RT-AccessCode': accessCode,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  if (secretKey) {
    headers['secretKey'] = secretKey;
  }

  while (pollCount < maxPolls) {
    await new Promise(resolve => setTimeout(resolve, pollDelayMs));
    try {
      const queryBody = {
        ...(orderNo ? { orderNo } : {}),
        pager: { pageNum: 1, pageSize: 50 },
      };

      const res = await fetchImpl(`${baseUrl}/esim/query`, {
        method: 'POST',
        headers,
        body: JSON.stringify(queryBody),
      });

      if (res.ok) {
        const json = await res.json();
        lastData = json;
        const allList = (json.obj && Array.isArray(json.obj.esimList)) ? json.obj.esimList : [];

        let matched = allList;
        if (orderNo) {
          matched = allList.filter(e => e.orderNo === orderNo);
        } else if (transactionId) {
          matched = allList.filter(e => e.transactionId === transactionId);
        }

        if (matched.length > 0) {
          esimList = matched;
          const allReady = matched.every(e => Boolean(e.iccid) && Boolean(e.ac || e.smdpAddress || e.qrCodeUrl));
          if (allReady) {
            isSuccess = true;
            break;
          }
        }
      }
    } catch (err) {
      console.log(`[eSIM Access Polling Warning]: ${err.message}`);
    }
    pollCount++;
  }

  if (!isSuccess && esimList.length > 0 && esimList.some(e => e.iccid)) {
    isSuccess = true;
  } else if (!isSuccess && pollCount >= maxPolls) {
    isFailed = true;
  }

  return {
    status: isSuccess ? 'COMPLETED' : (isFailed ? 'FAILED' : 'PENDING'),
    isSuccess,
    isFailed,
    esimList,
    errorMsg: isFailed ? `eSIM Access profile allocation timed out for order ${orderNo || transactionId}` : null,
    raw: lastData,
  };
}

async function getEsimUsage({
  baseUrl = esimAccessBaseUrl,
  accessCode,
  secretKey,
  esimTranNo,
  iccid,
  fetchImpl = fetch,
}) {
  if (!accessCode) return null;

  const headers = {
    'RT-AccessCode': accessCode,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  if (secretKey) {
    headers['secretKey'] = secretKey;
  }

  try {
    if (esimTranNo) {
      const res = await fetchImpl(`${baseUrl}/esim/usage/query`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ esimTranNoList: [String(esimTranNo)] }),
      });
      if (res.ok) {
        const json = await res.json();
        const usageList = json.obj?.esimUsageList || [];
        if (usageList.length > 0) {
          const item = usageList[0];
          const totalDataBytes = item.totalData || 0;
          const dataUsageBytes = item.dataUsage || 0;
          const totalMb = Math.round(totalDataBytes / (1024 * 1024));
          const usageMb = Math.round(dataUsageBytes / (1024 * 1024));
          const remainingMb = Math.max(0, totalMb - usageMb);
          return {
            dataRemainingMb: remainingMb,
            dataTotalMb: totalMb,
            dataUsageMb: usageMb,
            raw: json,
          };
        }
      }
    }

    if (iccid) {
      const res = await fetchImpl(`${baseUrl}/esim/query`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ iccid: String(iccid), pager: { pageNum: 1, pageSize: 1 } }),
      });
      if (res.ok) {
        const json = await res.json();
        const esimList = json.obj?.esimList || [];
        if (esimList.length > 0) {
          const item = esimList[0];
          const totalVolumeBytes = item.totalVolume || 0;
          const orderUsageBytes = item.orderUsage || 0;
          const totalMb = Math.round(totalVolumeBytes / (1024 * 1024));
          const usageMb = Math.round(orderUsageBytes / (1024 * 1024));
          const remainingMb = Math.max(0, totalMb - usageMb);
          return {
            dataRemainingMb: remainingMb,
            dataTotalMb: totalMb,
            dataUsageMb: usageMb,
            raw: json,
          };
        }
      }
    }
  } catch (err) {
    console.error(`[eSIM Access Usage Error]: ${err.message}`);
  }

  return null;
}

module.exports = {
  ESIMACCESS_SPEED_TIER_MAP,
  extractIsoCountries,
  normalizeEsimAccessOffer,
  fetchEsimCatalog,
  purchaseEsim,
  pollEsimOrderStatus,
  getEsimUsage,
};

