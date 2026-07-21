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

const EXECUTION_TYPE = 'refill_mini';
const BATCH_SIZE = 10;
const MAX_CONCURRENCY = 5;
const POLL_INTERVAL_MS = 10000;
const POLL_INTERVAL_BUSY_MS = 500;

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
const concurrencyLimit = pLimit(MAX_CONCURRENCY);

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

async function getCarrierDetails(simLineId) {
    const { data: lineData, error: lineError } = await supabase
        .from('sim_lines')
        .select(`
            id,
            phone_number,
            carriers (
                id,
                zen_carrier,
                dt_carrier,
                dt_country,
                api_provider,
                countries (
                    iso_code
                )
            )
        `)
        .eq('id', simLineId)
        .single();

    if (lineError || !lineData) {
        throw new Error(`Failed to fetch SIM line details: ${lineError ? lineError.message : 'Not found'}`);
    }

    const carrier = lineData.carriers;
    const countryCode = carrier?.countries?.iso_code;
    const provider = (carrier?.api_provider || 'zendit').toLowerCase();
    const carrierCode = provider === 'dtone' ? carrier?.dt_carrier : carrier?.zen_carrier;

    if (!carrierCode || !countryCode) {
        throw new Error(`Missing country or carrier mapping for SIM line ${simLineId} (provider: ${provider})`);
    }

    return {
        phoneNumber: lineData.phone_number,
        countryCode,
        carrierCode,
        provider
    };
}

async function executeRefill(execution) {
    console.log(`[executeRefill] Processing Auto Mini Refill Execution ID: ${execution.id}`);
    const executionProvider = (execution.api_provider || 'zendit').toLowerCase();

    try {
        const { phoneNumber, countryCode, carrierCode, provider } = await getCarrierDetails(execution.sim_line_id);
        const activeProvider = executionProvider || provider;

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

        // Purchase
        const gateway = execution.fulfillment_gateway || 'API';
        if (gateway === 'API') {
            let purchaseResult;
            let externalId;

            if (activeProvider === 'dtone') {
                externalId = `dt_${execution.id}`;
                console.log(`Executing DTone auto mini refill for ${phoneNumber}, offer: ${offerId}, external_id: ${externalId}`);
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
                    throw new Error(`DTone auto mini refill failed: ${pollRes.errorMsg || pollRes.status}`);
                }

                purchaseResult.transactionId = pollRes.transactionId || purchaseResult.transactionId;
            } else {
                externalId = `z_${execution.id}`;
                console.log(`Executing Zendit auto mini refill for ${phoneNumber}, offer: ${offerId}, transactionId: ${externalId}`);
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
                    throw new Error(`Zendit auto mini refill failed: ${pollRes.errorMsg || pollRes.status}`);
                }

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
                
            console.log(`Successfully completed Auto Mini Refill ${execution.id}`);

        } else {
            throw new Error(`Unsupported gateway: ${gateway}`);
        }

    } catch (error) {
        console.error(`Failed to execute refill ${execution.id}:`, error.message);
        // Premium users pay upfront; no wallet refund needed
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
            .rpc('claim_due_executions', {
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

console.log(`Worker (Auto Mini Refill) started.`);
pollQueue();
listenToInserts();
