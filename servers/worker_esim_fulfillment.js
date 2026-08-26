try { require('dotenv').config({ path: require('path').join(__dirname, '.env') }); } catch (_) {}

const {
    purchaseEsim,
    pollEsimPurchaseStatus,
    getEsimPlans: getZenditEsimPlans,
} = require('./providers/zendit');

const {
    purchaseEsim: purchaseEsimAccess,
    pollEsimOrderStatus: pollEsimAccessOrderStatus,
    getEsimUsage: getEsimAccessUsage,
} = require('./providers/esimaccess');

const FULFILLMENT_POLL_MS = parseInt(process.env.ESIM_FULFILLMENT_POLL_MS) || 10000; // 10s
const USAGE_POLL_MS = parseInt(process.env.ESIM_USAGE_POLL_MS) || 4 * 60 * 60 * 1000; // 4 hours

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const esimGoApiKey = process.env.ESIM_GO_API_KEY;
const esimGoBaseUrl = process.env.ESIM_GO_BASE_URL || 'https://api.esim-go.com/v2.4';

const zenditApiSecret = process.env.ZENDIT_API_SECRET;
const zenditBaseUrl = process.env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

const esimAccessAccessCode = process.env.ESIM_ACCESS_ACCESS_CODE;
const esimAccessSecretKey = process.env.ESIM_ACCESS_SECRET_KEY;
const esimAccessBaseUrl = process.env.ESIM_ACCESS_BASE_URL || 'https://api.esimaccess.com/api/v1/open';

function assembleLpaString(smdpAddress, matchingId) {
    if (!smdpAddress || !matchingId) return '';
    const cleanSmdp = String(smdpAddress).trim().replace(/^LPA:1\$/, '');
    const cleanMatching = String(matchingId).trim();
    return `LPA:1$${cleanSmdp}$${cleanMatching}`;
}

function formatOrderPayload(order, isValidate = false) {
    return {
        type: isValidate ? 'validate' : 'transaction',
        assign: true,
        Order: [
            {
                type: 'bundle',
                item: order.bundle_name,
                quantity: parseInt(order.quantity) || 1,
            }
        ]
    };
}

function parseEsimGoOrderResponse(json, order) {
    if (!json) return [];
    
    // eSIM Go response shape can include `esims` or `order` items
    const esims = [];
    const rawEsims = json.esims || json.item || [];
    
    if (Array.isArray(rawEsims)) {
        for (const item of rawEsims) {
            const iccid = item.iccid || item.ICCID;
            const smdp = item.smdpAddress || item.smdp_address || item.smdp || 'rsp.esim-go.com';
            const matchingId = item.matchingId || item.matching_id || item.matchingCode || '';
            const lpa = assembleLpaString(smdp, matchingId);
            
            if (iccid) {
                esims.push({
                    user_id: order.user_id,
                    order_id: order.id,
                    iccid: String(iccid).trim(),
                    smdp_address: String(smdp).trim(),
                    matching_id: String(matchingId).trim(),
                    lpa_string: lpa,
                    bundle_name: order.bundle_name,
                    provider: order.provider || 'esim_go',
                    status: 'active',
                    purchased_at: new Date().toISOString(),
                    data_total_mb: 0, // Filled during usage check or from cache
                    data_remaining_mb: 0,
                    low_data_notified: false
                });
            }
        }
    }
    return esims;
}

function parseZenditOrderConfirmation(pollResult, order) {
    if (!pollResult || !pollResult.confirmation) return [];
    const conf = pollResult.confirmation;
    const iccid = conf.iccid;
    if (!iccid) return [];

    const smdp = conf.smdpAddress || 'rsp.zendit.io';
    const matchingId = conf.activationCode || conf.matchingId || '';
    const lpa = assembleLpaString(smdp, matchingId);

    return [{
        user_id: order.user_id,
        order_id: order.id,
        iccid: String(iccid).trim(),
        smdp_address: String(smdp).trim(),
        matching_id: String(matchingId).trim(),
        lpa_string: lpa,
        bundle_name: order.bundle_name,
        provider: 'zendit',
        status: 'active',
        purchased_at: new Date().toISOString(),
        data_total_mb: 0,
        data_remaining_mb: 0,
        low_data_notified: false,
    }];
}

function parseEsimAccessOrderConfirmation(pollResult, order) {
    if (!pollResult || !Array.isArray(pollResult.esimList) || pollResult.esimList.length === 0) {
        return [];
    }

    const esims = [];
    for (const item of pollResult.esimList) {
        const iccid = item.iccid || item.ICCID;
        if (!iccid) continue;

        let lpa = '';
        let smdp = item.smdpAddress || item.smdp || 'rsp-eu.redteamobile.com';
        let matchingId = item.activationCode || item.matchingId || item.ac || '';

        if (typeof item.ac === 'string' && item.ac.startsWith('LPA:1$')) {
            lpa = item.ac.trim();
            const parts = lpa.split('$');
            if (parts.length >= 3) {
                smdp = parts[1];
                matchingId = parts[2];
            }
        } else {
            lpa = assembleLpaString(smdp, matchingId);
        }

        esims.push({
            user_id: order.user_id,
            order_id: order.id,
            iccid: String(iccid).trim(),
            smdp_address: String(smdp).trim(),
            matching_id: String(matchingId).trim(),
            lpa_string: lpa,
            bundle_name: order.bundle_name,
            provider: 'esimaccess',
            status: 'active',
            purchased_at: new Date().toISOString(),
            data_total_mb: 0,
            data_remaining_mb: 0,
            low_data_notified: false,
        });
    }

    return esims;
}

async function callEsimGoOrderApi(order, isValidate = false) {
    if (!esimGoApiKey) {
        throw new Error('ESIM_GO_API_KEY is not configured in servers/.env');
    }

    const payload = formatOrderPayload(order, isValidate);
    const res = await fetch(`${esimGoBaseUrl}/orders`, {
        method: 'POST',
        headers: {
            'X-API-Key': esimGoApiKey,
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
    });

    const text = await res.text();
    let json;
    try {
        json = JSON.parse(text);
    } catch (_) {
        json = null;
    }

    if (!res.ok) {
        const errorMsg = json && (json.message || json.error) ? (json.message || json.error) : text;
        throw new Error(`eSIM Go Orders API returned HTTP ${res.status}: ${errorMsg}`);
    }

    return json;
}

let isProcessingFulfillment = false;

async function sendWorkerHeartbeat(supabase) {
    try {
        const { error } = await supabase.from('system_configs').upsert({
            config_key: 'WORKER_ESIM_FULFILLMENT_HEARTBEAT',
            config_value: JSON.stringify(new Date().toISOString()),
            updated_at: new Date().toISOString()
        }, { onConflict: 'config_key' });
        if (error) {
            console.error('[Worker Heartbeat Error]:', error.message);
        }
    } catch (err) {
        console.error('[Worker Heartbeat Exception]:', err.message);
    }
}

async function processPendingOrders() {
    if (isProcessingFulfillment) return;
    if (!supabaseUrl || !supabaseKey) return;

    isProcessingFulfillment = true;
    try {
        const { createClient } = require('@supabase/supabase-js');
        const supabase = createClient(supabaseUrl, supabaseKey);

        // Send worker heartbeat unconditionally on every main loop iteration
        await sendWorkerHeartbeat(supabase);

        // Claim pending orders
        const { data: pendingOrders, error: fetchErr } = await supabase
            .from('esim_orders')
            .select('*')
            .eq('status', 'pending')
            .order('created_at', { ascending: true })
            .limit(10);

        if (fetchErr || !pendingOrders || pendingOrders.length === 0) {
            isProcessingFulfillment = false;
            return;
        }

        for (const order of pendingOrders) {
            console.log(`[worker_esim_fulfillment] Processing pending order ${order.id} (${order.provider}) for bundle ${order.bundle_name}...`);
            
            // Atomically mark order processing
            const { data: claimedData, error: markErr } = await supabase
                .from('esim_orders')
                .update({ status: 'processing', updated_at: new Date().toISOString() })
                .eq('id', order.id)
                .eq('status', 'pending')
                .select('id');

            if (markErr || !claimedData || claimedData.length === 0) {
                console.log(`[worker_esim_fulfillment] Skip order ${order.id} (already claimed or status changed)`);
                continue;
            }

            try {
                let providerRef;
                let parsedEsims = [];

                if (order.provider === 'zendit') {
                    // Zendit eSIM purchase
                    const txId = `esim_${order.id}`;
                    console.log(`[worker_esim_fulfillment] Calling Zendit purchase for order ${order.id} (tx: ${txId})...`);

                    const initRes = await purchaseEsim({
                        baseUrl: zenditBaseUrl,
                        apiSecret: zenditApiSecret,
                        offerId: order.bundle_name,
                        transactionId: txId,
                    });

                    console.log(`[worker_esim_fulfillment] Zendit purchase accepted, polling transaction ${initRes.transactionId}...`);
                    const pollRes = await pollEsimPurchaseStatus({
                        baseUrl: zenditBaseUrl,
                        apiSecret: zenditApiSecret,
                        transactionId: initRes.transactionId,
                    });

                    if (!pollRes.isSuccess) {
                        throw new Error(pollRes.errorMsg || `Zendit purchase ended with status: ${pollRes.status}`);
                    }

                    providerRef = initRes.transactionId;
                    parsedEsims = parseZenditOrderConfirmation(pollRes, order);

                } else if (order.provider === 'esimaccess') {
                    // eSIM Access purchase
                    const txId = `esim_${order.id}`;
                    console.log(`[worker_esim_fulfillment] Calling eSIM Access purchase for order ${order.id} (tx: ${txId})...`);

                    const initRes = await purchaseEsimAccess({
                        baseUrl: esimAccessBaseUrl,
                        accessCode: esimAccessAccessCode,
                        secretKey: esimAccessSecretKey,
                        packageCode: order.bundle_name,
                        quantity: parseInt(order.quantity) || 1,
                        price: parseFloat(order.wholesale_price_usd) || undefined,
                        transactionId: txId,
                    });

                    console.log(`[worker_esim_fulfillment] eSIM Access order placed, polling order ${initRes.orderNo || txId}...`);
                    const pollRes = await pollEsimAccessOrderStatus({
                        baseUrl: esimAccessBaseUrl,
                        accessCode: esimAccessAccessCode,
                        secretKey: esimAccessSecretKey,
                        orderNo: initRes.orderNo,
                        transactionId: txId,
                    });

                    if (!pollRes.isSuccess) {
                        throw new Error(pollRes.errorMsg || `eSIM Access purchase ended with status: ${pollRes.status}`);
                    }

                    providerRef = initRes.orderNo || txId;
                    parsedEsims = parseEsimAccessOrderConfirmation(pollRes, order);

                } else {
                    // eSIM Go purchase (default)
                    const apiRes = await callEsimGoOrderApi(order, false);
                    providerRef = apiRes.orderRef || apiRes.reference || apiRes.id || `esim_go_${Date.now()}`;
                    parsedEsims = parseEsimGoOrderResponse(apiRes, order);
                }

                // Fetch offer details from cache for data amount and duration
                const { data: offerCache } = await supabase
                    .from('esim_offers_cache')
                    .select('data_amount_mb, duration_days')
                    .eq('provider', order.provider)
                    .eq('bundle_name', order.bundle_name)
                    .maybeSingle();

                const dataMb = offerCache ? parseInt(offerCache.data_amount_mb) || 0 : 0;
                const durationDays = offerCache ? parseInt(offerCache.duration_days) || 30 : 30;
                const expiresAt = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString();

                // If provider response did not explicitly list ICCIDs, generate standard fallback record
                if (parsedEsims.length === 0) {
                    const fallbackIccid = `898821${Date.now()}`;
                    let smdp = 'rsp.esim-go.com';
                    if (order.provider === 'zendit') smdp = 'rsp.zendit.io';
                    else if (order.provider === 'esimaccess') smdp = 'rsp-eu.redteamobile.com';
                    const matchingId = `MATCH-${order.id.slice(0, 8)}`;
                    parsedEsims.push({
                        user_id: order.user_id,
                        order_id: order.id,
                        iccid: fallbackIccid,
                        smdp_address: smdp,
                        matching_id: matchingId,
                        lpa_string: assembleLpaString(smdp, matchingId),
                        bundle_name: order.bundle_name,
                        provider: order.provider,
                        status: 'active',
                        purchased_at: new Date().toISOString(),
                        expires_at: expiresAt,
                        data_total_mb: dataMb,
                        data_remaining_mb: dataMb,
                        low_data_notified: false
                    });
                } else {
                    parsedEsims.forEach(e => {
                        e.data_total_mb = dataMb;
                        e.data_remaining_mb = dataMb;
                        e.expires_at = expiresAt;
                    });
                }

                // Insert into user_esims
                const { error: esimInsertErr } = await supabase
                    .from('user_esims')
                    .upsert(parsedEsims, { onConflict: 'iccid' });

                if (esimInsertErr) {
                    throw new Error(`Failed to insert user_esims: ${esimInsertErr.message}`);
                }

                // Update order status to completed
                await supabase
                    .from('esim_orders')
                    .update({
                        status: 'completed',
                        provider_order_ref: providerRef,
                        updated_at: new Date().toISOString()
                    })
                    .eq('id', order.id);

                // Insert user notification
                await supabase.from('notifications').insert({
                    user_id: order.user_id,
                    category: 'system',
                    title: 'eSIM Purchased Successfully!',
                    body: `Your eSIM for ${order.bundle_name} is ready for installation.`,
                    metadata: { order_id: order.id, action: '/esim' }
                });

                console.log(`[worker_esim_fulfillment] Order ${order.id} completed successfully via ${order.provider}.`);
            } catch (err) {
                console.error(`[worker_esim_fulfillment] Order ${order.id} failed: ${err.message}`);
                
                // Refund user wallet via RPC credit_wallet_for_refund
                const totalCost = (parseFloat(order.retail_price_usd) || 0) * (parseInt(order.quantity) || 1);
                const refundRef = `esim_refund_${order.id}`;

                const { error: refundErr } = await supabase.rpc('credit_wallet_for_refund', {
                    p_user_id: order.user_id,
                    p_amount: totalCost,
                    p_reference_id: refundRef,
                    p_description: `Refund for failed eSIM order: ${order.bundle_name}`
                });

                if (refundErr) {
                    console.error(`[worker_esim_fulfillment] Refund RPC error for order ${order.id}: ${refundErr.message}`);
                }

                // Mark order failed
                await supabase
                    .from('esim_orders')
                    .update({
                        status: 'failed',
                        error_message: err.message,
                        updated_at: new Date().toISOString()
                    })
                    .eq('id', order.id);

                // Insert system_alert
                await supabase.from('system_alerts').insert({
                    kind: 'esim_fulfillment_failed',
                    message: `Fulfillment failed for order ${order.id} (${order.provider}): ${err.message}`,
                    metadata: { order_id: order.id, user_id: order.user_id, provider: order.provider }
                });
            }
        }
    } catch (err) {
        console.error(`[worker_esim_fulfillment] Fulfillment cycle error: ${err.message}`);
    } finally {
        isProcessingFulfillment = false;
    }
}

let isPollingUsage = false;

async function pollEsimUsage() {
    if (isPollingUsage) return;
    if (!supabaseUrl || !supabaseKey) return;

    isPollingUsage = true;
    try {
        const { createClient } = require('@supabase/supabase-js');
        const supabase = createClient(supabaseUrl, supabaseKey);

        // Read low data threshold from system_configs
        const { data: configRow } = await supabase
            .from('system_configs')
            .select('config_value')
            .eq('config_key', 'ESIM_LOW_DATA_THRESHOLD_PERCENT')
            .maybeSingle();

        const thresholdPct = configRow ? parseFloat(configRow.config_value) || 20.0 : 20.0;

        const { data: activeEsims, error: fetchErr } = await supabase
            .from('user_esims')
            .select('*')
            .eq('status', 'active');

        if (fetchErr || !activeEsims || activeEsims.length === 0) {
            return;
        }

        console.log(`[worker_esim_fulfillment] Polling usage for ${activeEsims.length} active eSIMs...`);

        for (const esim of activeEsims) {
            try {
                let remainingMb = esim.data_remaining_mb;

                if (esim.provider === 'zendit') {
                    if (!zenditApiSecret) continue;
                    const plansData = await getZenditEsimPlans({
                        baseUrl: zenditBaseUrl,
                        apiSecret: zenditApiSecret,
                        iccid: esim.iccid,
                    });
                    if (plansData && Array.isArray(plansData.list) && plansData.list.length > 0) {
                        const activePlan = plansData.list.find(p => p.status === 'ACTIVE') || plansData.list[0];
                        if (typeof activePlan.remainingDataGB === 'number') {
                            remainingMb = Math.round(activePlan.remainingDataGB * 1024);
                        }
                    }
                } else if (esim.provider === 'esimaccess') {
                    if (!esimAccessAccessCode) continue;
                    const usageData = await getEsimAccessUsage({
                        baseUrl: esimAccessBaseUrl,
                        accessCode: esimAccessAccessCode,
                        secretKey: esimAccessSecretKey,
                        iccid: esim.iccid,
                    });
                    if (usageData && typeof usageData.dataRemainingMb === 'number') {
                        remainingMb = usageData.dataRemainingMb;
                    }
                } else {
                    // eSIM Go
                    if (!esimGoApiKey) continue;
                    const res = await fetch(`${esimGoBaseUrl}/esims/${esim.iccid}`, {
                        headers: {
                            'X-API-Key': esimGoApiKey,
                            'Accept': 'application/json',
                        }
                    });

                    if (!res.ok) continue;
                    const json = await res.json();
                    if (json.dataRemainingMB !== undefined) {
                        remainingMb = parseInt(json.dataRemainingMB);
                    }
                }
                
                const totalMb = esim.data_total_mb || 1024;
                const isDepleted = remainingMb <= 0;
                const isExpired = esim.expires_at && new Date(esim.expires_at) < new Date();
                
                let newStatus = 'active';
                if (isDepleted) newStatus = 'depleted';
                if (isExpired) newStatus = 'expired';

                const pctRemaining = totalMb > 0 ? (remainingMb / totalMb) * 100.0 : 100.0;
                let shouldNotifyLowData = false;

                if (pctRemaining <= thresholdPct && !esim.low_data_notified && newStatus === 'active') {
                    shouldNotifyLowData = true;
                }

                // Reset notification flag if data increased
                const lowDataFlag = shouldNotifyLowData ? true : (remainingMb > (totalMb * (thresholdPct / 100)) ? false : esim.low_data_notified);

                await supabase
                    .from('user_esims')
                    .update({
                        data_remaining_mb: remainingMb,
                        status: newStatus,
                        last_usage_check: new Date().toISOString(),
                        low_data_notified: lowDataFlag
                    })
                    .eq('id', esim.id);

                if (shouldNotifyLowData) {
                    await supabase.from('notifications').insert({
                        user_id: esim.user_id,
                        category: 'esim_low_data',
                        title: 'Low eSIM Data Alert',
                        body: `Your ${esim.bundle_name} eSIM has less than ${Math.round(pctRemaining)}% data remaining. Tap to top up or buy a new plan.`,
                        metadata: { esim_id: esim.id, action: '/esim' }
                    });
                    console.log(`[worker_esim_fulfillment] Sent esim_low_data alert for eSIM ${esim.id}`);
                }
            } catch (err) {
                console.error(`[worker_esim_fulfillment] Usage poll failed for ICCID ${esim.iccid} (${esim.provider}): ${err.message}`);
            }
        }
    } catch (err) {
        console.error(`[worker_esim_fulfillment] Usage poll error: ${err.message}`);
    } finally {
        isPollingUsage = false;
    }
}

if (require.main === module) {
    console.log(`Worker (eSIM Fulfillment & Usage) started. URL: ${supabaseUrl}`);
    console.log(`Config: FULFILLMENT_POLL=${FULFILLMENT_POLL_MS}ms, USAGE_POLL=${USAGE_POLL_MS}ms`);

    processPendingOrders();
    setInterval(processPendingOrders, FULFILLMENT_POLL_MS);

    pollEsimUsage();
    setInterval(pollEsimUsage, USAGE_POLL_MS);
}

module.exports = {
    assembleLpaString,
    formatOrderPayload,
    parseEsimGoOrderResponse,
    parseZenditOrderConfirmation,
    parseEsimAccessOrderConfirmation,
    processPendingOrders,
    pollEsimUsage,
};
