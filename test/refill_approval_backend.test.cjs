const { test } = require('node:test');
const assert = require('node:assert/strict');
const { resolveApprovalQuote, processApprovalQuotes } = require('../../backend-sync-wt/refill_approval_quotes');
const { createCatalogFetcher, resolveBestSupplierRoute } = require('../../backend-sync-wt/offer_validation');
const mappings = [{ provider: 'zendit', provider_country_code: 'SA', provider_carrier_code: 'STC' }];
const execution = { id: 'execution', sim_line_id: 'line', api_provider: 'zendit', offer_id: 'SKU',
  amount: 3.50, max_authorized_usd: 1, target_local_value: 20, target_local_currency: 'SAR' };
const offer = { offerId: 'SKU', enabled: true, priceType: 'FIXED',
  price: { fixed: 710, currency: 'USD', currencyDivisor: 100 },
  send: { min: 20, max: 20, currencyCode: 'SAR', currencyDivisor: 1 } };
const entitlement = { found: true, automation_eligible: true, effective_tier: 'premium' };
const input = { execution, mappings, entitlement, rates: {} };

test('refresh quotes 7.31 from supplier pricing even when the stale display says 3.50', async () => {
  const route = await resolveApprovalQuote({ ...input, fetchCatalogForSupplier: async (_,__,___,options) => {
    assert.equal(options.requireFresh,true); return [offer];
  }});
  assert.equal(route.totalChargeUsd,7.31);
  assert.equal(route.feeUsd,.21);
  assert.equal(execution.max_authorized_usd,1);
  assert.equal(route.offer,undefined);
});
test('entitlement lookup failure cannot produce an approval price', async () => {
  await assert.rejects(resolveApprovalQuote({ ...input, entitlement: null }), /not currently eligible/);
});
test('dispatch blocks a second price increase instead of exceeding the accepted quote', async () => {
  const route = await resolveBestSupplierRoute({ mappings, preferredProvider:'zendit',
    intent:{ offerId:'SKU',targetValue:20,targetCurrency:'SAR' },maxAuthorizedUsd:7.31,tier:'premium',rates:{},
    fetchCatalogFn:async()=>[{ ...offer, price:{...offer.price,fixed:800} }] });
  assert.equal(route.status,'needs_approval');
  assert.equal(route.totalChargeUsd,8.24);
});
test('fresh requests reject stale memory and database fallback on supplier outage', async () => {
  let down = false, calls = 0;
  const fetchCatalog = createCatalogFetcher({ provider:'zendit', baseUrl:'https://example.invalid',
    apiSecret:'test-only', supabase:{ from:()=>{ throw Error('must not use database fallback'); } },
    fetchImpl:async()=>{ calls++; if(down) throw Error('supplier offline'); return {ok:true,json:async()=>({list:[{...offer,productType:'TOPUP',subTypes:['Mobile Top Up']}]})}; } });
  assert.equal((await fetchCatalog('SA','STC')).length,1);
  down=true;
  await assert.rejects(fetchCatalog('SA','STC',{requireFresh:true}),/supplier offline/);
  assert.equal(calls,2);
});
test('quote jobs write only their result and never purchase, reserve money, or queue an execution', async () => {
  const writes=[];
  const db={
    rpc:async(name)=>{
      if(name==='claim_refill_approval_quotes') return {data:[{id:'quote',execution_snapshot:execution}]};
      if(name==='resolve_line_entitlement') return {data:entitlement};
      throw Error('Unexpected money or execution RPC '+name);
    },
    from:(table)=>{
      if(table==='fx_rates_for_costing') return {select:async()=>({data:[]})};
      assert.equal(table,'refill_approval_quotes');
      return {update:(data)=>{ writes.push(data); const builder={eq:()=>builder,then:(resolve)=>resolve({error:null})}; return builder; }};
    }
  };
  await processApprovalQuotes({supabase:db,executionType:'refill_mini',getCarrierDetails:async()=>({mappings}),fetchCatalogForSupplier:async()=>[offer]});
  assert.equal(writes.length,1);
  assert.equal(writes[0].status,'ready');
  assert.equal(writes[0].route.totalChargeUsd,7.31);
});
