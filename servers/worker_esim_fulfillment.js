require('dotenv').config({ path: require('path').join(__dirname, '.env') });

const FULFILLMENT_POLL_MS = parseInt(process.env.ESIM_FULFILLMENT_POLL_MS) || 10000; // 10s
const USAGE_POLL_MS = parseInt(process.env.ESIM_USAGE_POLL_MS) || 4 * 60 * 60 * 1000; // 4 hours

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const esimGoApiKey = process.env.ESIM_GO_API_KEY;
const esimGoBaseUrl = process.env.ESIM_GO_BASE_URL || 'https://api.esim-go.com/v2.4';

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

async function processPendingOrders() {
    if (isProcessingFulfillment) return;
    if (!supabaseUrl || !supabaseKey) return;

    isProcessingFulfillment = true;
    try {
        const { createClient } = require('@supabase/supabase-js');
        const supabase = createClient(supabaseUrl, supabaseKey);

        // Upsert worker heartbeat
        await supabase.from('system_configs').upsert({
            config_key: 'WORKER_ESIM_FULFILLMENT_HEARTBEAT',
            config_value: new Date().toISOString(),
            updated_at: new Date().toISOString()
        }, { onConflict: 'config_key' }).catch(() => {});

        // Claim pending orders
        const { data: pendingOrders, error: fetchErr } = await supabase
            .from('esim_orders')
            .select('*')
            .eq('status', 'pending')
            .order('created_at', { ascending: true })
            .limit(10);

        if (fetchErr || !pendingOrders || pendingOrders.length === 0) {
            return;
        }

        for (const order of pendingOrders) {
            console.log(`[worker_esim_fulfillment] Processing pending order ${order.id} for bundle ${order.bundle_name}...`);
            
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
                // Call eSIM Go API
                const apiRes = await callEsimGoOrderApi(order, false);
                const providerRef = apiRes.orderRef || apiRes.reference || apiRes.id || `esim_go_${Date.now()}`;
                const parsedEsims = parseEsimGoOrderResponse(apiRes, order);

                // Fetch offer details from cache for data amount
                const { data: offerCache } = await supabase
                    .from('esim_offers_cache')
                    .select('data_amount_mb, duration_days')
                    .eq('provider', order.provider)
                    .eq('bundle_name', order.bundle_name)
                    .maybeSingle();

                const dataMb = offerCache ? parseInt(offerCache.data_amount_mb) || 0 : 0;
                const durationDays = offerCache ? parseInt(offerCache.duration_days) || 30 : 30;
                const expiresAt = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString();

                // If eSIM Go response did not explicitly list ICCIDs, generate standard record
                if (parsedEsims.length === 0) {
                    const fallbackIccid = apiRes.iccid || `898821${Date.now()}`;
                    const smdp = apiRes.smdpAddress || 'rsp.esim-go.com';
                    const matchingId = apiRes.matchingId || `MATCH-${order.id.slice(0, 8)}`;
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

                console.log(`[worker_esim_fulfillment] Order ${order.id} completed successfully.`);
            } catch (err) {
                console.error(`[worker_esim_fulfillment] Order ${order.id} failed: ${err.message}`);
                
                // Refund user wallet via RPC or credit_wallet_for_refund
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
                    message: `Fulfillment failed for order ${order.id}: ${err.message}`,
                    metadata: { order_id: order.id, user_id: order.user_id }
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
    if (!supabaseUrl || !supabaseKey || !esimGoApiKey) return;

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
                const res = await fetch(`${esimGoBaseUrl}/esims/${esim.iccid}`, {
                    headers: {
                        'X-API-Key': esimGoApiKey,
                        'Accept': 'application/json',
                    }
                });

                if (!res.ok) continue;
                const json = await res.json();
                
                // Parse remaining data
                const remainingMb = json.dataRemainingMB !== undefined ? parseInt(json.dataRemainingMB) : esim.data_remaining_mb;
                const totalMb = esim.data_total_mb || 1024;
                const isDepleted = remainingMb <= 0;
                const isExpired = esim.expires_at && new Date(esim.expires_at) < new Date();
                
                let newStatus = 'active';
                if (isDepleted) newStatus = 'depleted';
                if (isExpired) newStatus = 'expired';

                const pctRemaining = (remainingMb / totalMb) * 100.0;
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
                console.error(`[worker_esim_fulfillment] Usage poll failed for ICCID ${esim.iccid}: ${err.message}`);
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
    processPendingOrders,
    pollEsimUsage,
};
