// Unit tests for the DingConnect PIN path (L phase).
//
// Everything here is a UNIT test against fixtures shaped like Ding's published
// API model. No live Ding response has ever been observed by this project, so
// these prove the parser's REFUSALS as carefully as its successes — the point
// of `extractPin` is that it returns null instead of guessing, and a test suite
// that only checks the happy path would let a future "helpful" loosening
// through unnoticed.
//
// Run: node --test servers/voucher_pin_test.js

const test = require('node:test');
const assert = require('node:assert');

const {
  isPinProduct,
  extractPin,
  extractSerial,
  fetchPinProducts,
  purchasePin,
  transferRefOf,
  processingStateOf,
} = require('./providers/ding');

const { toUsd, round2 } = require('./worker_voucher_stock');

// ---------------------------------------------------------------------------
// RedemptionMechanism
// ---------------------------------------------------------------------------
test('isPinProduct accepts ReadReceipt and rejects Immediate', () => {
  assert.equal(isPinProduct({ RedemptionMechanism: 'ReadReceipt' }), true);
  assert.equal(isPinProduct({ RedemptionMechanism: 'readreceipt' }), true);
  assert.equal(isPinProduct({ RedemptionMechanism: 'Immediate' }), false);
  assert.equal(isPinProduct({}), false);
  assert.equal(isPinProduct(null), false);
});

test('isPinProduct rejects ReadAdditionalInformation', () => {
  // Reported as a possible third value. It is not documented as carrying a PIN,
  // and buying against a guess costs real money.
  assert.equal(isPinProduct({ RedemptionMechanism: 'ReadAdditionalInformation' }), false);
});

// ---------------------------------------------------------------------------
// extractPin — structured params
// ---------------------------------------------------------------------------
test('extractPin reads a labelled ReceiptParams key', () => {
  assert.equal(extractPin({ ReceiptParams: { Pin: '1234-5678-9012' } }), '1234-5678-9012');
  assert.equal(extractPin({ ReceiptParams: { PIN_CODE: '998877' } }), '998877');
  assert.equal(extractPin({ ReceiptParams: { 'Voucher Code': 'ABCD1234' } }), 'ABCD1234');
});

test('extractPin ignores empty values', () => {
  assert.equal(extractPin({ ReceiptParams: { Pin: '   ' } }), null);
  assert.equal(extractPin({ ReceiptParams: { Pin: null } }), null);
});

test('extractPin does not treat an arbitrary param as a PIN', () => {
  // A receipt carries balances, dates and phone numbers. Picking one of those
  // yields a plausible, wrong, unusable voucher.
  assert.equal(extractPin({
    ReceiptParams: { Balance: '25.00', ExpiryDate: '2027-01-01', MSISDN: '96555512345' },
  }), null);
});

// ---------------------------------------------------------------------------
// extractPin — prose
// ---------------------------------------------------------------------------
test('extractPin scrapes a labelled line out of ReceiptText', () => {
  assert.equal(
    extractPin({ ReceiptText: 'Thank you. PIN: 4455 6677 8899\nDial *102# to redeem.' }),
    '4455 6677 8899'
  );
  assert.equal(
    extractPin({ ReceiptText: 'Recharge code = XY12AB34' }),
    'XY12AB34'
  );
});

test('extractPin refuses an UNLABELLED number in prose', () => {
  // The whole safety property. A bare number in a receipt is more likely to be
  // a balance or a short code than a voucher.
  assert.equal(extractPin({ ReceiptText: 'Your top-up of 100 PKR was successful. 987654' }), null);
  assert.equal(extractPin({ ReceiptText: 'Dial *123# for your balance.' }), null);
});

test('extractPin prefers ReceiptParams over ReceiptText', () => {
  assert.equal(extractPin({
    ReceiptParams: { Pin: 'FROM-PARAMS' },
    ReceiptText: 'PIN: FROM-TEXT-000',
  }), 'FROM-PARAMS');
});

test('extractPin returns null for an empty record', () => {
  assert.equal(extractPin({}), null);
  assert.equal(extractPin(null), null);
});

test('extractSerial reads serial/batch keys only', () => {
  assert.equal(extractSerial({ ReceiptParams: { SerialNumber: 'SN-001' } }), 'SN-001');
  assert.equal(extractSerial({ ReceiptParams: { Batch_Number: 'B7' } }), 'B7');
  assert.equal(extractSerial({ ReceiptParams: { Pin: '1234' } }), null);
});

// ---------------------------------------------------------------------------
// Field readers — the two names the adapter had wrong
// ---------------------------------------------------------------------------
test('transferRefOf unwraps the TransferId OBJECT', () => {
  // String({...}) would have produced "[object Object]" and been stored as the
  // transaction id, making every later poll unmatchable.
  assert.equal(
    transferRefOf({ TransferId: { TransferRef: 'T-9001', DistributorRef: 'v_1_0' } }),
    'T-9001'
  );
  assert.equal(transferRefOf({ TransferId: 'legacy-string' }), 'legacy-string');
  assert.equal(transferRefOf({}), null);
});

test('processingStateOf prefers the published field name', () => {
  assert.equal(processingStateOf({ ProcessingState: 'Complete' }), 'Complete');
  // Falls back so a live response carrying the old name still works.
  assert.equal(processingStateOf({ TransferRecordStatus: 'Completed' }), 'Completed');
  assert.equal(processingStateOf({}), null);
});

// ---------------------------------------------------------------------------
// fetchPinProducts
// ---------------------------------------------------------------------------
function fakeFetch(payload, { ok = true, status = 200 } = {}) {
  return async () => ({
    ok, status,
    json: async () => payload,
    text: async () => JSON.stringify(payload),
  });
}

test('fetchPinProducts keeps only ReadReceipt SKUs, cheapest first', async () => {
  const products = await fetchPinProducts({
    apiKey: 'k', countryCode: 'PK', carrierCode: 'ZNPK',
    fetchImpl: fakeFetch({
      ResultCode: 1,
      Items: [
        { SkuCode: 'A', RedemptionMechanism: 'Immediate',
          Minimum: { SendValue: 0.10, SendCurrencyIso: 'OMR' } },
        { SkuCode: 'B', RedemptionMechanism: 'ReadReceipt',
          Minimum: { SendValue: 0.50, SendCurrencyIso: 'OMR', ReceiveValue: 300, ReceiveCurrencyIso: 'PKR' } },
        { SkuCode: 'C', RedemptionMechanism: 'ReadReceipt',
          Minimum: { SendValue: 0.18, SendCurrencyIso: 'OMR', ReceiveValue: 100, ReceiveCurrencyIso: 'PKR' } },
      ],
    }),
  });

  assert.deepEqual(products.map(p => p.skuCode), ['C', 'B']);
  assert.equal(products[0].sendCurrency, 'OMR');
  assert.equal(products[0].receiveValue, 100);
  assert.equal(products[0].receiveCurrency, 'PKR');
});

test('fetchPinProducts keeps PIN SKUs that carry a validity period', async () => {
  // Unlike fetchCatalog(), which excludes them: a PIN product legitimately has
  // one, and filtering on it would empty most PIN shelves.
  const products = await fetchPinProducts({
    apiKey: 'k', countryCode: 'PK', carrierCode: 'ZNPK',
    fetchImpl: fakeFetch({
      Items: [{
        SkuCode: 'D', RedemptionMechanism: 'ReadReceipt', ValidityPeriodIso: 'P30D',
        Minimum: { SendValue: 0.30, SendCurrencyIso: 'OMR' },
      }],
    }),
  });
  assert.equal(products.length, 1);
  assert.equal(products[0].validityIso, 'P30D');
});

test('fetchPinProducts raises on a non-1 ResultCode even with HTTP 200', async () => {
  await assert.rejects(
    () => fetchPinProducts({
      apiKey: 'k', countryCode: 'PK', carrierCode: 'ZNPK',
      fetchImpl: fakeFetch({ ResultCode: 3, ErrorCodes: ['InvalidProvider'] }),
    }),
    /ResultCode 3/
  );
});

test('fetchPinProducts returns [] with no carrier code rather than fetching', async () => {
  const products = await fetchPinProducts({
    apiKey: 'k', countryCode: 'PK', carrierCode: null,
    fetchImpl: async () => { throw new Error('should not be called'); },
  });
  assert.deepEqual(products, []);
});

// ---------------------------------------------------------------------------
// purchasePin
// ---------------------------------------------------------------------------
test('purchasePin returns the PIN and the receipt', async () => {
  const result = await purchasePin({
    apiKey: 'k', skuCode: 'C', sendValue: 0.18, accountNumber: '923001234567',
    distributorRef: 'v_job_0',
    fetchImpl: fakeFetch({
      ResultCode: 1,
      TransferRecord: {
        TransferId: { TransferRef: 'T-42', DistributorRef: 'v_job_0' },
        ProcessingState: 'Complete',
        ReceiptText: 'PIN: 1111 2222 3333. Dial *123*PIN#',
        ReceiptParams: { Pin: '1111 2222 3333', SerialNumber: 'SN9' },
        Price: { SendValue: 0.19, SendCurrencyIso: 'OMR' },
      },
    }),
  });

  assert.equal(result.pin, '1111 2222 3333');
  assert.equal(result.serial, 'SN9');
  assert.equal(result.providerRef, 'T-42');
  assert.equal(result.processingState, 'Complete');
  assert.equal(result.chargedValue, 0.19);
  assert.equal(result.chargedCurrency, 'OMR');
  assert.match(result.instructions, /Dial \*123\*PIN#/);
});

test('purchasePin returns pin:null — not a throw — when the receipt is opaque', async () => {
  // Money was spent and a PIN exists in Ding's portal. This must be a
  // recoverable state, not a failure that loses the reference.
  const result = await purchasePin({
    apiKey: 'k', skuCode: 'C', sendValue: 0.18, accountNumber: '923001234567',
    distributorRef: 'v_job_1',
    fetchImpl: fakeFetch({
      TransferRecord: {
        TransferId: { TransferRef: 'T-43' },
        ProcessingState: 'Complete',
        ReceiptText: 'Transaction complete. Reference 55512.',
      },
    }),
  });

  assert.equal(result.pin, null);
  assert.equal(result.providerRef, 'T-43');
  assert.match(result.instructions, /Transaction complete/);
});

test('purchasePin throws when Ding returns ErrorCodes', async () => {
  await assert.rejects(
    () => purchasePin({
      apiKey: 'k', skuCode: 'C', sendValue: 0.18, accountNumber: '9230012',
      distributorRef: 'v_job_2',
      fetchImpl: fakeFetch({ ErrorCodes: ['InsufficientBalance'] }),
    }),
    /InsufficientBalance/
  );
});

test('purchasePin refuses without an account number', async () => {
  await assert.rejects(
    () => purchasePin({ apiKey: 'k', skuCode: 'C', accountNumber: null }),
    /accountNumber/
  );
});

// ---------------------------------------------------------------------------
// Worker FX — the guard the cost ceiling depends on
// ---------------------------------------------------------------------------
test('toUsd converts through fx_rates and refuses an unknown currency', () => {
  const rates = { OMR: 0.3845, PKR: 278.5 };
  // 0.18 OMR ≈ $0.468 — not $0.18. Treating it as USD would understate the
  // cost 2.6x and walk a purchase straight past the ceiling.
  assert.equal(round2(toUsd(0.18, 'OMR', rates)), 0.47);
  assert.equal(toUsd(5, 'USD', rates), 5);
  assert.equal(toUsd(100, 'XYZ', rates), null);
  assert.equal(toUsd(null, 'OMR', rates), null);
});

test('round2 rounds to cents', () => {
  assert.equal(round2(0.4681404), 0.47);
  assert.equal(round2(0.465), 0.47);
  assert.equal(round2(null), null);
});

test('round2 rounds a binary-inexact half DOWN, and that is fine here', () => {
  // 1.005 * 100 is 100.49999999999999 in IEEE-754, so this yields 1.00 rather
  // than the 1.01 decimal arithmetic would give. Recorded rather than papered
  // over: round2 only ever touches `cost_usd` and `face_value_usd`, which are
  // OUR cost of a voucher converted through FX — a half-cent there is noise
  // against a rate that moves daily. Nothing a subscriber is charged goes
  // through it: `amount_due_usd` is computed by offline_voucher_amount_due()
  // in Postgres numeric, where 1.005 rounds to 1.01.
  assert.equal(round2(1.005), 1);
});
