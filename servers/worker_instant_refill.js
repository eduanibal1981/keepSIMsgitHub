require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const { createClient } = require('@supabase/supabase-js');
const {
    createCatalogFetcher,
    resolveVerifiedOffer,
    chargedOfferPriceUsd,
    alertOfferTampering
} = require('./offer_validation');

const zenditProvider = require('./providers/zendit');
const dtoneProvider = require('./providers/dtone');

const EXECUTION_TYPE = 'refill_instant';
const CONCURRENCY_LIMIT = 5;
const BATCH_SIZE = 10;
const POLL_INTERVAL_MS = 3000;
const POLL_INTERVAL_BUSY_MS = 200;

function pLimit(concurrency) {
    const queue = [];
    let active = 0;
    const next = () => {
        if (queue.length > 0 && active < concurrency) {
            active++;
            const { fn, resolve, reject } = queue.shift();
            fn().then(resolve).catch(reject).finally(() => {
                active--;
                next();
            });
        }
    };
    return (fn) => new Promise((resolve, reject) => {
        queue.push({ fn, resolve, reject });
        next();
    });
}

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const zenditApiSecret = process.env.ZENDIT_API_SECRET;
const zenditBaseUrl = process.env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

const dtoneApiKey = process.env.DTONE_API_KEY;
const dtoneApiSecret = process.env.DTONE_API_SECRET;
const dtoneBaseUrl = process.env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

if (!supabaseUrl || !supabaseKey) {
    console.error('Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in servers/.env');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);
const concurrencyLimit = pLimit(CONCURRENCY_LIMIT);

const fetchZenditCatalog = createCatalogFetcher({
    provider: 'zendit',
    baseUrl: zenditBaseUrl,
    apiSecret: zenditApiSecret,
    ttlMs: 5 * 60 * 1000,
});

const fetchDtoneCatalog = createCatalogFetcher({
    provider: 'dtone',
    baseUrl: dtoneBaseUrl,
    apiKey: dtoneApiKey,
    apiSecret: dtoneApiSecret,
    ttlMs: 5 * 60 * 1000,
});

// K3: the per-supplier columns this used to read (zen_carrier, dt_carrier,
// dt_country, api_provider) no longer exist. `carrier_provider_map` holds one
// row per (carrier, supplier) with that supplier's own country and carrier
// codes, so adding a fifth supplier is a row, not a code change.
//
// It also takes `preferredProvider` now, which fixes a real defect the old
// shape hid: the caller resolved codes from the CARRIER's default supplier and
// then dispatched on the EXECUTION's supplier. Any execution stamped with a
// non-default provider — which is now every premium refill, since
// queue_premium_refill_executions stamps the winning supplier — would have
// called that supplier's API with the default supplier's carrier code and been
// told the product does not exist.
//
// `dt_country` was selected here and never read: it held a full country name
// ('Saudi Arabia') while every lookup joins on ISO-2.
async function getCarrierDetails(simLineId, preferredProvider = null) {
    const { data: lineData, error: lineError } = await supabase
        .from('sim_lines')
        .select('id, phone_number, carrier_id')
        .eq('id', simLineId)
        .single();

    if (lineError || !lineData) {
        throw new Error(`Failed to fetch SIM line details: ${lineError ? lineError.message : 'Not found'}`);
    }

    let query = supabase
        .from('carrier_provider_map')
        .select('provider, provider_country_code, provider_carrier_code, is_primary, priority')
        .eq('carrier_id', lineData.carrier_id)
        .eq('is_enabled', true);

    if (preferredProvider) {
        query = query.eq('provider', preferredProvider.toLowerCase());
    }

    const { data: maps, error: mapError } = await query
        .order('is_primary', { ascending: false })
        .order('priority', { ascending: true });

    if (mapError) {
        throw new Error(`Failed to resolve supplier mapping: ${mapError.message}`);
    }

    const mapping = (maps || [])[0];
    if (!mapping) {
        // Naming the provider matters: "no mapping" and "no mapping FOR DTONE"
        // are different faults with different fixes, and the old message could
        // not tell them apart.
        throw new Error(
            `No enabled supplier mapping for SIM line ${simLineId}` +
            (preferredProvider ? ` and provider ${preferredProvider}` : '')
        );
    }

    return {
        phoneNumber: lineData.phone_number,
        countryCode: mapping.provider_country_code,
        carrierCode: mapping.provider_carrier_code,
        provider: mapping.provider
    };
}

async function executeRefill(execution) {
    console.log(`[executeRefill] Processing Instant Refill Execution ID: ${execution.id}`);
    
    let walletDebited = false;
    const userId = execution.user_id;
    const amount = parseFloat(execution.amount);
    const paymentGateway = execution.payment_gateway_code || 'wallet';
    // No 'zendit' fallback any more. An unstamped execution takes whatever the
    // carrier's PRIMARY mapping says; defaulting to Zendit here is how a DTOne
    // carrier's refill got dispatched to a supplier that has never heard of it.
    const executionProvider = execution.api_provider
        ? execution.api_provider.toLowerCase()
        : null;

    try {
        // Codes are resolved FOR the supplier we are about to call, so the
        // carrier code and the API being called can no longer disagree.
        const { phoneNumber, countryCode, carrierCode, provider } =
            await getCarrierDetails(execution.sim_line_id, executionProvider);
        const activeProvider = provider;

        // Validation
        const chargedUsd = chargedOfferPriceUsd(execution);
        let topups;
        if (activeProvider === 'dtone') {
            if (!dtoneApiKey || !dtoneApiSecret) {
                throw new Error('DTone API credentials (DTONE_API_KEY, DTONE_API_SECRET) not configured on server.');
            }
            topups = await fetchDtoneCatalog(countryCode, carrierCode);
        } else {
            if (!zenditApiSecret) {
                throw new Error('Zendit API credentials (ZENDIT_API_SECRET) not configured on server.');
            }
            topups = await fetchZenditCatalog(countryCode, carrierCode);
        }

        let offerId = execution.offer_id;
        let offerValue = execution.offer_value != null ? parseFloat(execution.offer_value) : null;
        try {
            const resolved = resolveVerifiedOffer({
                topups,
                offerId,
                offerValue,
                chargedUsd,
                countryCode,
                zenCarrier: carrierCode
            });
            offerId = resolved.offerId;
            offerValue = resolved.offerValue;
        } catch (mismatchErr) {
            await alertOfferTampering(supabase, execution, mismatchErr.message);
            throw mismatchErr;
        }

        // Wallet Debit
        if (paymentGateway === 'wallet') {
            console.log(`Debiting wallet for user ${userId}, amount: ${amount} USD...`);
            const { data: debitSuccess, error: debitError } = await supabase
                .rpc('debit_wallet_for_topup', {
                    p_user_id: userId,
                    p_sim_line_id: execution.sim_line_id,
                    p_amount: amount,
                    p_description: `Instant Mobile Refill for SIM Line (${execution.sim_line_id})`,
                    p_reference_id: `exec_${execution.id}`
                });

            if (debitError) {
                throw new Error(`Wallet debit failed: ${debitError.message}`);
            }

            if (!debitSuccess) {
                throw new Error('Insufficient wallet balance');
            }

            walletDebited = true;
            console.log(`Wallet debited successfully for execution ${execution.id}`);
        } else {
            console.log(`Payment gateway is ${paymentGateway}; bypassing wallet debit.`);
        }

        // Execute Purchase
        const gateway = execution.fulfillment_gateway || 'API';

        if (gateway === 'API') {
            let purchaseResult;
            let externalId;

            if (activeProvider === 'dtone') {
                externalId = `dt_${execution.id}`;
                console.log(`Executing DTone purchase for ${phoneNumber}, offer: ${offerId}, external_id: ${externalId}`);
                purchaseResult = await dtoneProvider.purchase({
                    baseUrl: dtoneBaseUrl,
                    apiKey: dtoneApiKey,
                    apiSecret: dtoneApiSecret,
                    execution,
                    recipientPhone: phoneNumber,
                    offerId,
                    offerValue,
                    externalId
                });

                const pollRes = await dtoneProvider.pollStatus({
                    baseUrl: dtoneBaseUrl,
                    apiKey: dtoneApiKey,
                    apiSecret: dtoneApiSecret,
                    transactionId: purchaseResult.transactionId,
                    externalId
                });

                if (pollRes.isFailed) {
                    throw new Error(`DTone purchase failed: ${pollRes.errorMsg || pollRes.status}`);
                }

                console.log(`DTone transaction completed! Status: ${pollRes.status}`);
                purchaseResult.transactionId = pollRes.transactionId || purchaseResult.transactionId;

            } else {
                externalId = `z_${execution.id}`;
                console.log(`Executing Zendit purchase for ${phoneNumber}, offer: ${offerId}, transactionId: ${externalId}`);
                purchaseResult = await zenditProvider.purchase({
                    baseUrl: zenditBaseUrl,
                    apiSecret: zenditApiSecret,
                    execution,
                    recipientPhone: phoneNumber,
                    offerId,
                    offerValue,
                    externalId
                });

                const pollRes = await zenditProvider.pollStatus({
                    baseUrl: zenditBaseUrl,
                    apiSecret: zenditApiSecret,
                    transactionId: purchaseResult.transactionId
                });

                if (pollRes.isFailed) {
                    throw new Error(`Zendit purchase failed: ${pollRes.errorMsg || pollRes.status}`);
                }

                console.log(`Zendit transaction completed! Status: ${pollRes.status}`);
                purchaseResult.transactionId = pollRes.transactionId || purchaseResult.transactionId;
            }

            // Mark execution as success
            const { error: updateError } = await supabase
                .rpc('update_execution_status', { 
                    p_id: execution.id,
                    p_status: 'success',
                    p_reloadly_transaction_id: purchaseResult.transactionId || externalId 
                });
                
            if (updateError) {
                throw new Error(`Failed to update database status to success: ${updateError.message}`);
            }
                
            console.log(`Successfully completed Instant Refill ${execution.id}`);

        } else {
            throw new Error(`Unsupported gateway: ${gateway}`);
        }

    } catch (error) {
        console.error(`Failed to execute refill ${execution.id}:`, error.message);
        
        // Rollback (Refund) on Failure
        if (paymentGateway === 'wallet' && walletDebited) {
            console.log(`Attempting to refund wallet for failed execution ${execution.id}...`);
            const { error: refundError } = await supabase.rpc('credit_wallet_for_refund', {
                p_user_id: userId,
                p_sim_line_id: execution.sim_line_id,
                p_amount: amount,
                p_description: `Refund for failed instant refill execution ${execution.id}`,
                p_reference_id: `refund_exec_${execution.id}`
            });
            if (refundError) {
                if (refundError.code === '23505' || (refundError.message || '').includes('duplicate key')) {
                    console.log(`Refund for execution ${execution.id} already recorded. Skipping.`);
                } else {
                    console.error(`Refund failed:`, refundError.message);
                    await supabase.from('system_alerts').insert({
                        kind: 'refund_failed',
                        message: `Refund of ${amount} USD failed for execution ${execution.id} (user ${userId}): ${refundError.message}`,
                        details: { execution_id: execution.id, user_id: userId, amount: amount }
                    });
                }
            } else {
                console.log(`Refund successful.`);
            }
        }

        await markExecutionFailed(execution.id, error.message);
    }
}

async function markExecutionFailed(executionId, reason) {
    const { error } = await supabase
        .rpc('update_execution_failed', { 
            p_id: executionId,
            p_reason: reason
        });
        
    if (error) {
        console.error(`Failed to update database status to failed:`, error.message);
    }
}

let pollTimer = null;
let isPolling = false;

async function pollQueue() {
    if (isPolling) return;
    isPolling = true;

    try {
        const { data: executions, error } = await supabase
            .rpc('claim_instant_executions', {
                p_execution_type: EXECUTION_TYPE,
                p_limit: BATCH_SIZE
            });

        if (error) throw error;

        if (executions && executions.length > 0) {
            console.log(`[${new Date().toISOString()}] Claimed ${executions.length} executions. Processing...`);

            await Promise.all(
                executions.map(exec => concurrencyLimit(() => executeRefill(exec)))
            );

            schedulePoll(POLL_INTERVAL_BUSY_MS);
        } else {
            schedulePoll(POLL_INTERVAL_MS);
        }
    } catch (err) {
        console.error('[pollQueue] Error polling the queue:', err);
        schedulePoll(POLL_INTERVAL_MS);
    } finally {
        isPolling = false;
    }
}

function schedulePoll(intervalMs) {
    if (pollTimer) clearTimeout(pollTimer);
    pollTimer = setTimeout(pollQueue, intervalMs);
}

function listenToInserts() {
    supabase
        .channel('topup_executions_inserts')
        .on(
            'postgres_changes',
            {
                event: 'INSERT',
                schema: 'public',
                table: 'topup_executions',
                filter: `execution_type=eq.${EXECUTION_TYPE}`
            },
            (payload) => {
                console.log(`[Realtime] New insert detected: ${payload.new.id}. Triggering immediate queue poll...`);
                pollQueue();
            }
        )
        .subscribe();
}

console.log(`Worker (Instant Refill) started.`);
pollQueue();
listenToInserts();
