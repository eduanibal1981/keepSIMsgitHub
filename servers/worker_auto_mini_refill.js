require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL || 'https://zwxswagokhgbuzrrbnhr.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('Error: Please set SUPABASE_URL and SUPABASE_ANON_KEY environment variables.');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

const EXECUTION_TYPE = 'refill_mini';
const POLL_INTERVAL_MS = 30000; // 30 seconds
const BATCH_SIZE = 50;

async function executeRefill(execution) {
    console.log(`\n--- Processing Auto Refill Mini ${execution.id} ---`);
    console.log(`Amount: ${execution.amount} ${execution.currency}`);
    console.log(`Provider: ${execution.api_provider || 'N/A'}`);
    
    try {
        if (execution.fulfillment_gateway === 'API') {
            console.log(`[TODO] Making HTTP request to ${execution.api_provider} API...`);
            // Add actual Reloadly/Zendit logic here
            
            // Mark as success on completion
            await supabase
                .from('topup_executions')
                .update({ status: 'success', executed_at: new Date().toISOString() })
                .eq('id', execution.id);
            console.log(`Successfully completed Auto Refill ${execution.id}`);
        } else {
            console.log(`Unsupported gateway for auto-refill: ${execution.fulfillment_gateway}`);
            await supabase
                .from('topup_executions')
                .update({ status: 'failed', failure_reason: 'Unsupported gateway' })
                .eq('id', execution.id);
        }
    } catch (error) {
        console.error(`Failed to execute refill ${execution.id}:`, error);
        await supabase
            .from('topup_executions')
            .update({ status: 'failed', failure_reason: error.message })
            .eq('id', execution.id);
    }
}

async function pollQueue() {
    try {
        // Use the Stored Procedure to atomically fetch and lock due items
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
// Run once immediately on startup
pollQueue();
