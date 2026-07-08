const zenditApiSecret = 'sand_0296bcc7-526e-4efb-b4f9-8b11108e7c396a29abd0a371a4c9f33194dd';
const zenditBaseUrl = 'https://api.zendit.io/v1';

async function testZendit(type, value) {
    const requestBody = {
        transactionId: `test_test_${Date.now()}`,
        offerId: "VODAFONE_EG_OPEN",
        recipientPhoneNumber: "+201095351020",
        value: {
            value: value,
            type: type
        }
    };

    const purchaseResponse = await fetch(`${zenditBaseUrl}/topups/purchases`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${zenditApiSecret}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestBody)
    });

    const errText = await purchaseResponse.text();
    console.log(`Type '${type}', Value ${value}: ${purchaseResponse.status} - ${errText}`);
}

async function run() {
    await testZendit("ZEND", 1600); // 16 EGP (in range 800 - 20000)
    await testZendit("PRICE", 50); // 0.50 USD (in range 25 - 623)
    await testZendit("COST", 40); // 0.40 USD (in range 20 - 503)
}

run();
