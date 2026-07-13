const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '/home/abdal/keepsims_backend/.env' });

console.log('SUPABASE_URL:', process.env.SUPABASE_URL);

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function run() {
  const { data, error } = await supabase
    .from('topup_executions')
    .select('id,status,execution_type,execution_time,created_at');
  
  console.log('Data:', data);
  console.log('Error:', error);
}

run();
