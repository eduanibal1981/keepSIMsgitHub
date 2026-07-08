require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL || 'https://zwxswagokhgbuzrrbnhr.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('Error: Please set SUPABASE_URL and SUPABASE_ANON_KEY environment variables.');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

const EXECUTION_TYPE = 'refill_custom';
const POLL_INTERVAL_MS = 30000; // 30 seconds
const BATCH_SIZE = 50;

async function executeRefill(execution) {
    console.log(`\n--- Processing Auto Refill Mini ${execution.id} ---`);
    console.log(`Amount: ${execution.amount} ${execution.currency}`);
    console.log(`Provider: ${execution.api_provider || 'N/A'}`);
    
    // We assume the execution record contains the user_id
    const userId = execution.user_id; 
    const amount = parseFloat(execution.amount);

    try {

        // ==========================================
        // STEP 1: Verify & Deduct Wallet Balance -- Production prevents double spending by using a database transaction or atomic operation
        // ==========================================
        
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
            return; // Abort completely!
        }

        // --- At this exact point, the money has been safely deducted ---
        
        // Record the transaction for the user's ledger
        const txData = {
            user_id: userId,
            amount: amount, 
            type: 'topup_debit',
            description: `Auto-refill deduction for execution ${execution.id}`,
            reference_id: `exec_${execution.id}`,
        };
        await supabase.from('wallet_transactions').insert(txData);
        console.log(`Successfully deducted ${amount} from wallet.`);

        // ==========================================
        // STEP 2: Call Telecom API
        // ==========================================
        if (execution.fulfillment_gateway === 'API') {
            console.log(`[TODO] Making HTTP request to ${execution.api_provider} API...`);
            
            // ---> Add actual Reloadly/Zendit API logic here <---
            // const apiResult = await myTelecomProvider.topup(...)
            // if (!apiResult.success) throw new Error('Telecom API Failed');
            

// ... [Telecom API Call Succeeds] ...

// 1. Mark current execution as success
await supabase
    .from('topup_executions')
    .update({ status: 'success', executed_at: new Date().toISOString() })
    .eq('id', execution.id);
console.log(`Successfully completed Auto Refill ${execution.id}`);
// ==========================================
// 2. SPAWN THE NEXT REFILL (Rolling Window)
// ==========================================
if (execution.scheduled_topup_id) {
    // Fetch the parent schedule to get the frequency rules
    const { data: parentSchedule } = await supabase
        .from('scheduled_topups')
        .select('frequency_days, is_active, amount, currency')
        .eq('id', execution.scheduled_topup_id)
        .single();

    // Only spawn the next one if the user hasn't paused the schedule!
    if (parentSchedule && parentSchedule.is_active) {
        
        // Calculate next date (e.g., +90 days)
        const nextDate = new Date();
        nextDate.setDate(nextDate.getDate() + parentSchedule.frequency_days);

        // Insert the next pending execution
        await supabase.from('topup_executions').insert({
            scheduled_topup_id: execution.scheduled_topup_id,
            sim_line_id: execution.sim_line_id,
            user_id: execution.user_id,
            amount: parentSchedule.amount,         // Pull latest amount just in case they changed it
            currency: parentSchedule.currency,
            status: 'pending',
            execution_type: 'refill_custom',
            execution_time: nextDate.toISOString(),
            fulfillment_gateway: 'API',
            api_provider: execution.api_provider
        });
        
        console.log(`Spawned next refill for ${nextDate.toISOString()}`);
    }
}
        } else {
            throw new Error(`Unsupported gateway: ${execution.fulfillment_gateway}`);
        }

    } catch (error) {
        console.error(`Failed to execute refill ${execution.id}:`, error);
        
        // ==========================================
        // STEP 3: Rollback (Refund) on Failure
        // ==========================================
        // If it failed *after* we deducted the wallet, we must refund the user
        if (error.message !== 'Insufficient wallet balance' && error.message !== 'Wallet not found for user.') {
             console.log(`Attempting to refund wallet for failed execution ${execution.id}...`);
             // Fetch current balance again
             const { data: currentWallet } = await supabase.from('wallets').select('*').eq('user_id', userId).single();
             if (currentWallet) {
                 const refundedBalance = currentWallet.balance + amount;
                 await supabase.from('wallets').update({ balance: refundedBalance }).eq('id', currentWallet.id);
                 
                 // Log the refund transaction
                 await supabase.from('wallet_transactions').insert({
                    user_id: userId,
                    wallet_id: currentWallet.id,
                    amount: amount,
                    balance_before: currentWallet.balance,
                    balance_after: refundedBalance,
                    type: 'refund',
                    description: `Refund for failed auto-refill execution ${execution.id}`,
                    reference_id: `refund_exec_${execution.id}`,
                 });
                 console.log(`Refund successful.`);
             }
        }

        // Mark execution as failed
        await markExecutionFailed(execution.id, error.message);
    }
}

async function markExecutionFailed(executionId, reason) {
    await supabase
        .from('topup_executions')
        .update({ status: 'failed', failure_reason: reason })
        .eq('id', executionId);
}

// ... pollQueue() remains exactly the same ...
async function pollQueue() {
    try {
        const { data: executions, error } = await supabase
            .rpc('claim_due_executions', { p_execution_type: EXECUTION_TYPE, p_limit: BATCH_SIZE });
            
        if (error) throw error;
        
        if (executions && executions.length > 0) {
            console.log(`[${new Date().toISOString()}] Claimed ${executions.length} due executions for ${EXECUTION_TYPE}. Processing...`);
            for (const execution of executions) {
                await executeRefill(execution);
            }
        }
    } catch (err) {
        console.error('Error polling the queue:', err);
    }
}

console.log(`Worker (Auto Refill Mini) started. Polling every ${POLL_INTERVAL_MS / 1000} seconds...`);
setInterval(pollQueue, POLL_INTERVAL_MS);
pollQueue();