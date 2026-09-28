require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const { createClient } = require('@supabase/supabase-js');
const {
    createCatalogFetcher,
    resolveVerifiedOffer,
    chargedOfferPriceUsd,
    alertOfferTampering,
    loadFxRates
} = require('./offer_validation');

const zenditProvider = require('./providers/zendit');
const dtoneProvider = require('./providers/dtone');
const reloadlyProvider = require('./providers/reloadly');
const dingProvider = require('./providers/ding');

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

const reloadlyClientId = process.env.RELOADLY_CLIENT_ID;
const reloadlyClientSecret = process.env.RELOADLY_CLIENT_SECRET;
const reloadlyBaseUrl = process.env.RELOADLY_BASE_URL || 'https://topups.reloadly.com';

const dingApiKey = process.env.DING_API_KEY;
const dingBaseUrl = process.env.DING_BASE_URL || 'https://api.dingconnect.com/api/V1';

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
    supabase,
});

const fetchDtoneCatalog = createCatalogFetcher({
    provider: 'dtone',
    baseUrl: dtoneBaseUrl,
    apiKey: dtoneApiKey,
    apiSecret: dtoneApiSecret,
    ttlMs: 5 * 60 * 1000,
    supabase,
});

const fetchReloadlyCatalog = createCatalogFetcher({
    provider: 'reloadly',
    baseUrl: reloadlyBaseUrl,
    clientId: reloadlyClientId,
    clientSecret: reloadlyClientSecret,
    ttlMs: 5 * 60 * 1000,
    supabase,
});

const fetchDingCatalog = createCatalogFetcher({
    provider: 'ding',
    baseUrl: dingBaseUrl,
    apiKey: dingApiKey,
    ttlMs: 5 * 60 * 1000,
    supabase,
});

// K3: the per-supplier columns this used to read (zen_carrier, dt_carrier,
// dt_country, api_provider) no longer exist. `carrier_provider_map` holds one
// row per (carrier, supplier) with that supplier's own country and carrier
// codes, so adding a fifth supplier is a row, not a code change.
//
// It also takes `preferredProvider` now, which fixes a real defect the old
// shape hid: the caller resolved codes from the CARRIER's default supplier and
// then dispatched on the EXECUTION's supplier. Any execution stamped with a
// non-default provider â€” which is now every premium refill, since
// queue_premium_refill_executions stamps the winning supplier â€” would have
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
    
    let walletHoldId = execution.wallet_hold_id || null;
    const userId = execution.user_id;
    const amount = parseFloat(execution.amount);
    const paymentGateway = execution.payment_gateway_code || 'wallet';
    // No 'zendit' fallback any more. An unstamped execution takes whatever the
    // carrier's PRIMARY mapping says; defaulting to Zendit here is how a DTOne
    // carrier's refill got dispatched to a supplier that has never heard of it.
    const executionProvider = execution.api_provider
        ? execution.api_provider.toLowerCase()
        : null;

    let activeProvider = executionProvider;

    try {
        // Codes are resolved FOR the supplier we are about to call, so the
        // carrier code and the API being called can no longer disagree.
        const { phoneNumber, countryCode, carrierCode, provider } =
            await getCarrierDetails(execution.sim_line_id, executionProvider);
        activeProvider = provider;

        if (!execution.api_provider && activeProvider) {
            await supabase
                .from('topup_executions')
                .update({ api_provider: activeProvider })
                .eq('id', execution.id);
        }

        // Validation
        const chargedUsd = chargedOfferPriceUsd(execution);
        let topups;
        if (activeProvider === 'ding') {
            if (!dingApiKey) {
                throw new Error('Ding API credentials (DING_API_KEY) not configured on server.');
            }
            topups = await fetchDingCatalog(countryCode, carrierCode);
        } else if (activeProvider === 'dtone') {
            if (!dtoneApiKey || !dtoneApiSecret) {
                throw new Error('DTone API credentials (DTONE_API_KEY, DTONE_API_SECRET) not configured on server.');
            }
            topups = await fetchDtoneCatalog(countryCode, carrierCode);
        } else if (activeProvider === 'reloadly') {
            if (!reloadlyClientId || !reloadlyClientSecret) {
                throw new Error('Reloadly credentials (RELOADLY_CLIENT_ID, RELOADLY_CLIENT_SECRET) not configured on server.');
            }
            topups = await fetchReloadlyCatalog(countryCode, carrierCode);
        } else {
            if (!zenditApiSecret) {
                throw new Error('Zendit API credentials (ZENDIT_API_SECRET) not configured on server.');
            }
            topups = await fetchZenditCatalog(countryCode, carrierCode);
        }

        const rates = await loadFxRates(supabase);
        let offerId = execution.offer_id;
        let offerValue = execution.offer_value != null ? parseFloat(execution.offer_value) : null;
        try {
            const resolved = resolveVerifiedOffer({
                topups,
                offerId,
                offerValue,
                chargedUsd,
                countryCode,
                zenCarrier: carrierCode,
                rates
            });
            offerId = resolved.offerId;
            offerValue = resolved.offerValue;
        } catch (mismatchErr) {
            await alertOfferTampering(supabase, execution, mismatchErr.message);
            throw mismatchErr;
        }

        // Wallet Hold Reservation
        if (!walletHoldId && paymentGateway === 'wallet') {
            console.log(`Reserving wallet funds for user ${userId}, amount: ${amount} USD...`);
            const { data: reservedHoldId, error: holdError } = await supabase
                .rpc('reserve_wallet_funds', {
                    p_user_id: userId,
                    p_amount: amount,
                    p_order_type: 'refill_instant',
                    p_order_reference_id: `exec_${execution.id}`,
                    p_reason: `Instant Mobile Refill for SIM Line (${execution.sim_line_id})`
                });

            if (holdError) {
                throw new Error(`Wallet reservation failed: ${holdError.message}`);
            }

            walletHoldId = reservedHoldId;
            console.log(`Wallet hold reserved successfully: ${walletHoldId}`);

            await supabase
                .from('topup_executions')
                .update({ wallet_hold_id: walletHoldId })
                .eq('id', execution.id);
        } else if (walletHoldId) {
            console.log(`Reusing existing wallet hold ${walletHoldId} for execution ${execution.id}`);
        } else {
            console.log(`Payment gateway is ${paymentGateway}; bypassing wallet reservation.`);
        }

        // Execute Purchase
        const gateway = execution.fulfillment_gateway || 'API';

        if (gateway === 'API') {
            let purchaseResult;
            let externalId;
            let pollRes = null;

            if (activeProvider === 'ding') {
                externalId = `d_${execution.id}`;
                console.log(`Executing Ding purchase for ${phoneNumber}, offer: ${offerId}, external_id: ${externalId}`);
                purchaseResult = await dingProvider.purchase({
                    baseUrl: dingBaseUrl,
                    apiKey: dingApiKey,
                    execution,
                    recipientPhone: phoneNumber,
                    offerId,
                    offerValue,
                    externalId
                });

                if (['Complete', 'Completed', 'Success'].includes(purchaseResult.status)) {
                    pollRes = {
                        status: purchaseResult.status,
                        isSuccess: true,
                        isFailed: false,
                        transactionId: purchaseResult.transactionId,
                        raw: purchaseResult.raw?.TransferRecord || purchaseResult.raw
                    };
                } else {
                    pollRes = await dingProvider.pollStatus({
                        baseUrl: dingBaseUrl,
                        apiKey: dingApiKey,
                        transactionId: purchaseResult.transactionId,
                        externalId
                    });
                }

                if (!pollRes.isSuccess) {
                    throw new Error(`Ding purchase failed: ${pollRes.errorMsg || pollRes.status}`);
                }

                console.log(`Ding transaction completed! Status: ${pollRes.status}`);
                purchaseResult.transactionId = pollRes.transactionId || purchaseResult.transactionId;

            } else if (activeProvider === 'dtone') {
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

                pollRes = await dtoneProvider.pollStatus({
                    baseUrl: dtoneBaseUrl,
                    apiKey: dtoneApiKey,
                    apiSecret: dtoneApiSecret,
                    transactionId: purchaseResult.transactionId,
                    externalId
                });

                // Only an explicit success counts as delivered. `isFailed` alone
                // let an INDETERMINATE poll - no verdict after 12 tries, or an
                // unreachable API - fall through and be recorded as success.
                // A false failure is recoverable: both adapters adopt-on-retry
                // against the same external_id, so a retry cannot double-charge.
                // A false success is not recoverable at all.
                if (!pollRes.isSuccess) {
                    throw new Error(`DTone purchase failed: ${pollRes.errorMsg || pollRes.status}`);
                }

                console.log(`DTone transaction completed! Status: ${pollRes.status}`);
                purchaseResult.transactionId = pollRes.transactionId || purchaseResult.transactionId;

            } else if (activeProvider === 'reloadly') {
                externalId = `rl_${execution.id}`;
                console.log(`Executing Reloadly purchase for ${phoneNumber}, offer: ${offerId}, external_id: ${externalId}`);
                purchaseResult = await reloadlyProvider.purchase({
                    baseUrl: reloadlyBaseUrl,
                    clientId: reloadlyClientId,
                    clientSecret: reloadlyClientSecret,
                    execution,
                    recipientPhone: phoneNumber,
                    offerId,
                    offerValue,
                    externalId,
                    countryCode
                });

                pollRes = await reloadlyProvider.pollStatus({
                    baseUrl: reloadlyBaseUrl,
                    clientId: reloadlyClientId,
                    clientSecret: reloadlyClientSecret,
                    transactionId: purchaseResult.transactionId,
                    externalId
                });

                if (!pollRes.isSuccess) {
                    throw new Error(`Reloadly purchase failed: ${pollRes.errorMsg || pollRes.status}`);
                }

                console.log(`Reloadly transaction completed! Status: ${pollRes.status}`);
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

                pollRes = await zenditProvider.pollStatus({
                    baseUrl: zenditBaseUrl,
                    apiSecret: zenditApiSecret,
                    transactionId: purchaseResult.transactionId
                });

                // Only an explicit success counts as delivered. `isFailed` alone
                // let an INDETERMINATE poll - no verdict after 12 tries, or an
                // unreachable API - fall through and be recorded as success.
                // A false failure is recoverable: both adapters adopt-on-retry
                // against the same external_id, so a retry cannot double-charge.
                // A false success is not recoverable at all.
                if (!pollRes.isSuccess) {
                    throw new Error(`Zendit purchase failed: ${pollRes.errorMsg || pollRes.status}`);
                }

                console.log(`Zendit transaction completed! Status: ${pollRes.status}`);
                purchaseResult.transactionId = pollRes.transactionId || purchaseResult.transactionId;
            }

            // If a digital PIN voucher was returned, notify the subscriber immediately
            const pinPayload = (activeProvider === 'dtone')
                ? (pollRes?.raw?.pin || purchaseResult?.raw?.pin || (Array.isArray(pollRes?.raw) ? pollRes.raw[0]?.pin : null) || null)
                : null;
            let pinCode = null;
            let pinSerial = null;
            let pinInstructions = null;

            if (pinPayload && pinPayload.code) {
                pinCode = String(pinPayload.code);
                pinSerial = pinPayload.serial ? String(pinPayload.serial) : null;
                pinInstructions = pinPayload.usage_info || `Dial *1400*${pinCode}# on your device to apply airtime.`;
                try {
                    await supabase.from('notifications').insert({
                        user_id: userId,
                        category: 'system',
                        title: 'Your Recharge PIN is Ready',
                        body: `Your PIN code is ${pinCode}. ${pinInstructions}`,
                        sim_line_id: execution.sim_line_id,
                        action_url: `/sim-lines/${execution.sim_line_id}`
                    });
                } catch (notifErr) {
                    console.warn(`[notif] Failed to create PIN notification: ${notifErr.message}`);
                }
            }

            // Capture wallet hold on success
            if (walletHoldId) {
                console.log(`Capturing wallet hold ${walletHoldId} for execution ${execution.id}...`);
                const isSetupRefill = execution.funding_kind === 'setup_hold';
                const description = isSetupRefill
                    ? `Setup Refill for SIM Line (${execution.sim_line_id})`
                    : `Instant Mobile Refill for SIM Line (${execution.sim_line_id})`;
                const { error: captureError } = await supabase
                    .rpc('capture_wallet_hold', {
                        p_hold_id: walletHoldId,
                        p_txn_type: 'topup_debit',
                        p_description: description,
                        p_metadata: {
                            execution_id: execution.id,
                            sim_line_id: execution.sim_line_id,
                            provider: activeProvider,
                            transaction_id: purchaseResult.transactionId || externalId,
                            order_type: isSetupRefill ? 'setup_refill' : 'refill_instant',
                            funding_kind: execution.funding_kind || null
                        }
                    });
                if (captureError) {
                    console.error(`Failed to capture wallet hold ${walletHoldId}:`, captureError.message);
                }
            }

            // Mark execution as success
            const { error: updateError } = await supabase
                .rpc('update_execution_status', { 
                    p_id: execution.id,
                    p_status: 'success',
                    p_reloadly_transaction_id: purchaseResult.transactionId || externalId,
                    p_pin_code: pinCode,
                    p_pin_serial: pinSerial,
                    p_redeem_instructions: pinInstructions
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
        
        // Release wallet hold on failure
        if (walletHoldId) {
            console.log(`Releasing wallet hold ${walletHoldId} for failed execution ${execution.id}...`);
            const { error: releaseError } = await supabase
                .rpc('release_wallet_hold', {
                    p_hold_id: walletHoldId,
                    p_reason: `Refill failed: ${error.message}`
                });
            if (releaseError) {
                console.error(`Failed to release wallet hold ${walletHoldId}:`, releaseError.message);
            } else {
                console.log(`Wallet hold ${walletHoldId} released successfully.`);
            }
        }

        await markExecutionFailed(execution.id, error.message, activeProvider);
    }
}

async function markExecutionFailed(executionId, reason, provider = null) {
    const { error } = await supabase
        .rpc('update_execution_failed', { 
            p_id: executionId,
            p_reason: reason
        });
        
    if (error) {
        console.error(`Failed to update database status to failed:`, error.message);
    }

    if (provider) {
        try {
            await supabase
                .from('topup_executions')
                .update({ api_provider: provider })
                .eq('id', executionId);
        } catch (_) {}
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
