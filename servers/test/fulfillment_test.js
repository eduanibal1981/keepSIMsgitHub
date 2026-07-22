const test = require('node:test');
const assert = require('node:assert/strict');
const {
    assembleLpaString,
    formatOrderPayload,
    parseEsimGoOrderResponse,
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
