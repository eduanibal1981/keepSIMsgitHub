require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL || 'https://zwxswagokhgbuzrrbnhr.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTAwODcwMiwiZXhwIjoyMDk0NTg0NzAyfQ.bcVWXC8n8oTwD6EsRCy66YRJUNa6yddIeCUPlgDFw94';
const zenditApiSecret = process.env.ZENDIT_API_SECRET || 'sand_0296bcc7-526e-4efb-b4f9-8b11108e7c396a29abd0a371a4c9f33194dd';
const zenditBaseUrl = 'https://api.zendit.io/v1';

if (!supabaseUrl || !supabaseKey) {
    console.error('Error: Please set SUPABASE_URL and SUPABASE_ANON_KEY environment variables.');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

const EXECUTION_TYPE = 'refill_instant';
const POLL_INTERVAL_MS = 10000; // 10 seconds for instant refill
const BATCH_SIZE = 50;

async function executeRefill(execution) {
    console.log(`\n--- Processing Instant Refill ${execution.id} ---`);
    console.log(`Amount: ${execution.amount} ${execution.currency}`);
    console.log(`Provider: ${execution.api_provider || 'N/A'}`);
    
    const userId = execution.user_id; 
    const amount = parseFloat(execution.amount);

    try {
        // ==========================================
        // STEP 1: Verify & Deduct Wallet Balance (Only if Wallet)
        // ==========================================
        if (execution.payment_gateway_code === 'wallet') {
            const { data: isSuccess, error: rpcError } = await supabase.rpc('deduct_wallet_atomic', { 
                p_user_id: userId, 
                p_amount: amount 
            });

            if (rpcError) {
                throw new Error(`Database error: ${rpcError.message}`);
            }

            if (!isSuccess) {
                console.log(`Insufficient funds. Required: ${amount}`);
                await markExecutionFailed(execution.id, 'Insufficient wallet balance');
                return;
            }
            
            // Record the transaction for the user's ledger
            const txData = {
                user_id: userId,
                amount: amount, 
                type: 'topup_debit',
                description: `Instant refill deduction for execution ${execution.id}`,
                reference_id: `exec_${execution.id}`,
            };
            await supabase.from('wallet_transactions').insert(txData);
            console.log(`Successfully deducted ${amount} from wallet.`);
        } else {
            console.log(`Payment method is ${execution.payment_gateway_code}. Skipping wallet deduction.`);
        }

        // ==========================================
        // STEP 1: Fetch SIM Line details (Phone & Country)
        // ==========================================
        const { data: simLine, error: simError } = await supabase
            .from('sim_lines')
            .select(`
                phone_number,
                countries!inner (
                    iso_code
                )
            `)
            .eq('id', execution.sim_line_id)
            .single();

        if (simError || !simLine) {
            throw new Error(`Failed to fetch sim line details: ${simError?.message || 'Not found'}`);
        }

        const phoneNumber = simLine.phone_number.startsWith('+') ? simLine.phone_number : `+${simLine.phone_number}`;
        const countryCode = simLine.countries.iso_code;

        console.log(`Target Phone: ${phoneNumber}, Country: ${countryCode}`);

        // ==========================================
        // STEP 2: Call Zendit API
        // ==========================================
        const gateway = execution.fulfillment_gateway || 'API';
        if (gateway === 'API') {
            console.log(`Making HTTP request to Zendit API...`);

            if (!execution.offer_id) {
                throw new Error(`offer_id is missing in execution record. Cannot process.`);
            }

            console.log(`Using Zendit Offer ID: ${execution.offer_id}`);

            const transactionId = `z_sand_${Date.now()}`;

            const requestBody = {
                transactionId: transactionId,
                offerId: execution.offer_id,
                recipientPhoneNumber: phoneNumber
            };
            if (execution.offer_value) {
                requestBody.value = { value: execution.offer_value, type: 'ZEND' };
            }

            // 2c. Execute Purchase
            const purchaseResponse = await fetch(`${zenditBaseUrl}/topups/purchases`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${zenditApiSecret}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(requestBody)
            });

            if (!purchaseResponse.ok && purchaseResponse.status !== 201) {
                const errText = await purchaseResponse.text();
                throw new Error(`Zendit Purchase API Error: ${purchaseResponse.status} - ${errText}`);
            }

            let purchaseData = await purchaseResponse.json();
            let currentStatus = purchaseData.status || 'PENDING';

            // 2d. Poll Status
            let pollCount = 0;
            while (['ACCEPTED', 'PENDING', 'AUTHORIZED', 'IN_PROGRESS'].includes(currentStatus) && pollCount < 5) {
                await new Promise(resolve => setTimeout(resolve, 2000));
                try {
                    const checkResponse = await fetch(`${zenditBaseUrl}/topups/purchases/${transactionId}`, {
                        headers: {
                            'Authorization': `Bearer ${zenditApiSecret}`,
                            'Content-Type': 'application/json'
                        }
                    });
                    if (checkResponse.ok) {
                        const checkData = await checkResponse.json();
                        purchaseData = checkData;
                        currentStatus = checkData.status || currentStatus;
                    }
                } catch (err) {
                    console.log(`Polling warning: ${err.message}`);
                }
                pollCount++;
            }

            if (currentStatus === 'FAILED' || currentStatus === 'DECLINED') {
                const errorMsg = purchaseData.error?.message || `Transaction failed with status: ${currentStatus}`;
                throw new Error(`Zendit failed: ${errorMsg}`);
            }

            console.log(`Zendit transaction successful! Status: ${currentStatus}`);

            // ==========================================
            // STEP 3: Mark execution as success
            // ==========================================
            await supabase
                .from('topup_executions')
                .update({ 
                    status: 'success', 
                    executed_at: new Date().toISOString(),
                    reloadly_transaction_id: purchaseData.transactionId || transactionId 
                })
                .eq('id', execution.id);
                
            console.log(`Successfully completed Instant Refill ${execution.id}`);

        } else {
            throw new Error(`Unsupported gateway: ${gateway}`);
        }

    } catch (error) {
        console.error(`Failed to execute refill ${execution.id}:`, error.message);
        
        // ==========================================
        // STEP 4: Rollback (Refund) on Failure
        // ==========================================
        if (execution.payment_gateway_code === 'wallet') {
            console.log(`Attempting to refund wallet for failed execution ${execution.id}...`);
            const { data: currentWallet } = await supabase.from('wallets').select('*').eq('user_id', userId).single();
            if (currentWallet) {
                const refundedBalance = currentWallet.balance + amount;
                await supabase.from('wallets').update({ balance: refundedBalance }).eq('id', currentWallet.id);
                
                await supabase.from('wallet_transactions').insert({
                   user_id: userId,
                   wallet_id: currentWallet.id,
                   amount: amount,
                   balance_before: currentWallet.balance,
                   balance_after: refundedBalance,
                   type: 'refund',
                   description: `Refund for failed instant refill execution ${execution.id}`,
                   reference_id: `refund_exec_${execution.id}`,
                });
                console.log(`Refund successful.`);
            }
        } else {
            console.log(`Payment method is ${execution.payment_gateway_code}. No wallet refund needed.`);
        }

        await markExecutionFailed(execution.id, error.message);
    }
}

async function markExecutionFailed(executionId, reason) {
    await supabase
        .from('topup_executions')
        .update({ status: 'failed', failure_reason: reason })
        .eq('id', executionId);
}

async function pollQueue() {
    try {
        const { data: executions, error } = await supabase
            .from('topup_executions')
            .select('*')
            .eq('status', 'routing')
            .eq('execution_type', EXECUTION_TYPE)
            .limit(BATCH_SIZE);
            
        if (error) throw error;
        
        if (executions && executions.length > 0) {
            console.log(`[${new Date().toISOString()}] Claimed ${executions.length} due executions for ${EXECUTION_TYPE}. Processing...`);
            for (const execution of executions) {
                // Atomically update status to processing to claim it
                const { data: updated, error: updateError } = await supabase
                    .from('topup_executions')
                    .update({ status: 'processing' })
                    .eq('id', execution.id)
                    .eq('status', 'routing')
                    .select();
                
                if (updateError) {
                    console.error(`Failed to lock execution ${execution.id}:`, updateError.message);
                    continue;
                }
                
                if (updated && updated.length > 0) {
                    await executeRefill(execution);
                }
            }
        }
    } catch (err) {
        console.error('Error polling the queue:', err);
    }
}

console.log(`Worker (Instant Refill) started. Polling every ${POLL_INTERVAL_MS / 1000} seconds...`);
setInterval(pollQueue, POLL_INTERVAL_MS);
pollQueue();
