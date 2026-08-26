const test = require('node:test');
const assert = require('node:assert/strict');
const {
    assembleLpaString,
    formatOrderPayload,
    parseEsimGoOrderResponse,
    parseZenditOrderConfirmation,
    parseEsimAccessOrderConfirmation,
} = require('../worker_esim_fulfillment.js');

test('assembleLpaString — builds correct LPA format', () => {
    const result = assembleLpaString('rsp.esim-go.com', 'MATCH-12345');
    assert.equal(result, 'LPA:1$rsp.esim-go.com$MATCH-12345');
});

test('assembleLpaString — handles pre-prefixed LPA strings safely', () => {
    const result = assembleLpaString('LPA:1$rsp.esim-go.com', 'MATCH-67890');
    assert.equal(result, 'LPA:1$rsp.esim-go.com$MATCH-67890');
});

test('formatOrderPayload — creates transaction order payload', () => {
    const order = { bundle_name: 'esim_1GB_7D_US', quantity: 2 };
    const payload = formatOrderPayload(order, false);

    assert.equal(payload.type, 'transaction');
    assert.equal(payload.assign, true);
    assert.equal(payload.Order.length, 1);
    assert.equal(payload.Order[0].item, 'esim_1GB_7D_US');
    assert.equal(payload.Order[0].quantity, 2);
});

test('formatOrderPayload — creates validate dry-run payload', () => {
    const order = { bundle_name: 'esim_5GB_30D_EU', quantity: 1 };
    const payload = formatOrderPayload(order, true);

    assert.equal(payload.type, 'validate');
    assert.equal(payload.assign, true);
});

test('parseEsimGoOrderResponse — parses ICCID and LPA string correctly', () => {
    const mockOrder = { id: 'ord-123', user_id: 'usr-456', bundle_name: 'esim_1GB_7D_US', provider: 'esim_go' };
    const mockApiResponse = {
        orderRef: 'ref-789',
        esims: [
            {
                iccid: '8988211000000000001',
                smdpAddress: 'rsp.esim-go.com',
                matchingId: 'MATCH-ABC'
            }
        ]
    };

    const parsed = parseEsimGoOrderResponse(mockApiResponse, mockOrder);
    assert.equal(parsed.length, 1);
    assert.equal(parsed[0].iccid, '8988211000000000001');
    assert.equal(parsed[0].lpa_string, 'LPA:1$rsp.esim-go.com$MATCH-ABC');
    assert.equal(parsed[0].user_id, 'usr-456');
});

test('parseZenditOrderConfirmation — parses Zendit ICCID and LPA string correctly', () => {
    const mockOrder = {
        id: 'ord-zen-999',
        user_id: 'usr-zen-111',
        bundle_name: 'ESIM-EG-10D-ULE-NOROAM',
        provider: 'zendit',
    };

    const mockPollResult = {
        status: 'DONE',
        isSuccess: true,
        confirmation: {
            iccid: '8988219999999999999',
            smdpAddress: 'rsp.zendit.io',
            activationCode: 'ACT-ZEN-XYZ-123',
            redemptionInstructions: 'Scan QR code to install',
        },
    };

    const parsed = parseZenditOrderConfirmation(mockPollResult, mockOrder);
    assert.equal(parsed.length, 1);
    assert.equal(parsed[0].iccid, '8988219999999999999');
    assert.equal(parsed[0].smdp_address, 'rsp.zendit.io');
    assert.equal(parsed[0].matching_id, 'ACT-ZEN-XYZ-123');
    assert.equal(parsed[0].lpa_string, 'LPA:1$rsp.zendit.io$ACT-ZEN-XYZ-123');
    assert.equal(parsed[0].provider, 'zendit');
    assert.equal(parsed[0].user_id, 'usr-zen-111');
});

test('parseEsimAccessOrderConfirmation — parses eSIM Access ICCID and LPA string correctly', () => {
    const mockOrder = {
        id: 'ord-ea-888',
        user_id: 'usr-ea-222',
        bundle_name: 'CKH139',
        provider: 'esimaccess',
    };

    const mockPollResult = {
        status: 'COMPLETED',
        isSuccess: true,
        esimList: [
            {
                orderNo: 'B23121220718406',
                transactionId: 'esim_ord-ea-888',
                iccid: '89852000263320905385',
                ac: 'LPA:1$rsp-eu.redteamobile.com$E93D112C3AA247E2AF9BCAFD830EE991',
                qrCodeUrl: 'https://p.qrsim.net/a9e40a2fccbe47c5b025221881d3c90a.png',
                smdpStatus: 'RELEASED',
                totalVolume: 5368709120,
                totalDuration: 30,
                durationUnit: 'DAY',
            }
        ]
    };

    const parsed = parseEsimAccessOrderConfirmation(mockPollResult, mockOrder);
    assert.equal(parsed.length, 1);
    assert.equal(parsed[0].iccid, '89852000263320905385');
    assert.equal(parsed[0].smdp_address, 'rsp-eu.redteamobile.com');
    assert.equal(parsed[0].matching_id, 'E93D112C3AA247E2AF9BCAFD830EE991');
    assert.equal(parsed[0].lpa_string, 'LPA:1$rsp-eu.redteamobile.com$E93D112C3AA247E2AF9BCAFD830EE991');
    assert.equal(parsed[0].provider, 'esimaccess');
    assert.equal(parsed[0].user_id, 'usr-ea-222');
});

test('parseEsimAccessOrderConfirmation — handles empty or invalid poll result', () => {
    const mockOrder = { id: 'ord-ea-888', user_id: 'usr-ea-222', bundle_name: 'CKH139', provider: 'esimaccess' };
    assert.deepEqual(parseEsimAccessOrderConfirmation(null, mockOrder), []);
    assert.deepEqual(parseEsimAccessOrderConfirmation({}, mockOrder), []);
    assert.deepEqual(parseEsimAccessOrderConfirmation({ esimList: [] }, mockOrder), []);
});

test('purchaseEsim (esimaccess) — submits order with correct price unit and transactionId', async () => {
    const { purchaseEsim } = require('../providers/esimaccess');
    let capturedUrl, capturedHeaders, capturedBody;

    const mockFetch = async (url, options) => {
        capturedUrl = url;
        capturedHeaders = options.headers;
        capturedBody = JSON.parse(options.body);
        const payload = {
            success: true,
            errorCode: '0',
            obj: { orderNo: 'B23121220718406' }
        };
        return {
            ok: true,
            status: 200,
            text: async () => JSON.stringify(payload),
            json: async () => payload,
        };
    };

    const res = await purchaseEsim({
        baseUrl: 'https://api.esimaccess.com/api/v1/open',
        accessCode: 'test-access-code',
        secretKey: 'test-secret-key',
        packageCode: 'CKH139',
        quantity: 2,
        price: 11.25, // $11.25 -> 112500 in 1/10000 USD
        transactionId: 'esim_ord_test_999',
        fetchImpl: mockFetch,
    });

    assert.equal(capturedUrl, 'https://api.esimaccess.com/api/v1/open/esim/order');
    assert.equal(capturedHeaders['RT-AccessCode'], 'test-access-code');
    assert.equal(capturedHeaders['secretKey'], 'test-secret-key');
    assert.equal(capturedBody.transactionId, 'esim_ord_test_999');
    assert.equal(capturedBody.packageInfoList[0].packageCode, 'CKH139');
    assert.equal(capturedBody.packageInfoList[0].price, 112500);
    assert.equal(capturedBody.packageInfoList[0].count, 2);
    assert.equal(capturedBody.amount, 225000);
    assert.equal(res.orderNo, 'B23121220718406');
    assert.equal(res.status, 'ACCEPTED');
});

test('getEsimUsage (esimaccess) — computes remaining MB accurately from bytes', async () => {
    const { getEsimUsage } = require('../providers/esimaccess');

    const mockFetch = async (url, options) => {
        return {
            ok: true,
            status: 200,
            json: async () => ({
                success: true,
                errorCode: '0',
                obj: {
                    esimUsageList: [
                        {
                            esimTranNo: 'TRN-12345',
                            totalData: 5368709120, // 5120 MB
                            dataUsage: 1073741824, // 1024 MB used
                        }
                    ]
                }
            })
        };
    };

    const usage = await getEsimUsage({
        baseUrl: 'https://api.esimaccess.com/api/v1/open',
        accessCode: 'test-access-code',
        secretKey: 'test-secret-key',
        esimTranNo: 'TRN-12345',
        fetchImpl: mockFetch,
    });

    assert.equal(usage.dataTotalMb, 5120);
    assert.equal(usage.dataUsageMb, 1024);
    assert.equal(usage.dataRemainingMb, 4096);
});
