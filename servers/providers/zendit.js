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

module.exports = {
  fetchCatalog,
  normalizeZenditProduct,
  purchase,
  pollStatus,
};
