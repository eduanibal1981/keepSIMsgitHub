const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '/home/abdal/keepsims_backend/.env' });

console.log('SUPABASE_URL:', process.env.SUPABASE_URL);

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function run() {
  const targetId = '1a55847b-8d52-452c-a8b4-d5aff8c253bc';
  
  // 1. Check status before
  const { data: before, error: errBefore } = await supabase
    .from('topup_executions')
    .select('id, status, execution_type, execution_time')
    .eq('id', targetId);
  console.log('--- Before RPC ---');
  console.log('Row:', before);
  console.log('Error:', errBefore);

  // 2. Call RPC
  console.log('Calling claim_due_executions...');
  const { data: claimData, error: claimErr } = await supabase
    .rpc('claim_due_executions', {
      p_execution_type: 'refill_mini',
      p_limit: 20
    });
  console.log('Claimed:', claimData);
  console.log('RPC Error:', claimErr);

  // 3. Check status after
  const { data: after, error: errAfter } = await supabase
    .from('topup_executions')
    .select('id, status, execution_type, execution_time')
    .eq('id', targetId);
  console.log('--- After RPC ---');
  console.log('Row:', after);
  console.log('Error:', errAfter);
}

run();
