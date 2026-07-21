const zenditBaseUrl = process.env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

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

  return all.filter(o =>
    o.enabled && o.productType === 'TOPUP' && (o.subTypes || []).includes('Mobile Top Up'));
}

async function purchase({ baseUrl = zenditBaseUrl, apiSecret, execution, recipientPhone, offerId, offerValue, externalId, fetchImpl = fetch }) {
  const transactionId = externalId || `z_${execution.id}`;
  const purchaseBody = {
    transactionId,
    recipientPhoneNumber: recipientPhone,
    offerId,
  };
  if (offerValue != null) {
    purchaseBody.value = offerValue;
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

  const isSuccess = ['SUCCESS', 'COMPLETED'].includes(currentStatus);
  const isFailed = ['FAILED', 'DECLINED'].includes(currentStatus);

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
  purchase,
  pollStatus,
};
