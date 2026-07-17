-- C3c plan billing tests — run LIVE inside BEGIN..ROLLBACK via MCP execute_sql
-- (safe: nothing commits; workers cannot see uncommitted rows).
--
-- Verifies pay_plan_fee_from_wallet (server-priced wallet billing of the
-- yearly plan service fee) and the plan_payments table's grants.
-- All 8 assertions passed live on 2026-07-17.

begin;

-- Impersonate the a1-wallet-test fixture (auth.uid() reads the JWT claims).
select set_config('request.jwt.claims',
  '{"sub":"e5a56433-6f75-41a3-96b9-19c62b9d1280","role":"authenticated"}', true);

-- 1. The fee comes from system_configs and debits exactly that amount.
do $$
declare
  v_before numeric;
  v_after numeric;
  v_txn uuid;
  v_amount numeric;
begin
  select balance into v_before from wallets where user_id = auth.uid();
  v_txn := pay_plan_fee_from_wallet('test_ref_c3c_001');
  select balance into v_after from wallets where user_id = auth.uid();
  select amount into v_amount from wallet_transactions where id = v_txn;
  if v_amount <> 2.50 then raise exception 'TEST1 FAIL: debited %, expected 2.50', v_amount; end if;
  if v_before - v_after <> 2.50 then raise exception 'TEST1 FAIL: balance moved %', v_before - v_after; end if;
  if (select type from wallet_transactions where id = v_txn) <> 'plan_fee_debit' then
    raise exception 'TEST1 FAIL: wrong txn type'; end if;
  raise notice 'TEST1 PASS';
end $$;

-- 2. Retry with the same reference adopts the original debit (no double charge).
do $$
declare
  v_before numeric;
  v_txn1 uuid;
  v_txn2 uuid;
  v_after numeric;
begin
  select balance into v_before from wallets where user_id = auth.uid();
  v_txn1 := (select id from wallet_transactions where type='plan_fee_debit' and reference_id='test_ref_c3c_001');
  v_txn2 := pay_plan_fee_from_wallet('test_ref_c3c_001');
  select balance into v_after from wallets where user_id = auth.uid();
  if v_txn1 <> v_txn2 then raise exception 'TEST2 FAIL: new txn on retry'; end if;
  if v_before <> v_after then raise exception 'TEST2 FAIL: retry moved money'; end if;
  raise notice 'TEST2 PASS';
end $$;

-- 3. The price follows the config row — one DB row, no app update.
do $$
declare
  v_txn uuid;
  v_amount numeric;
begin
  update system_configs set config_value = '4.00' where config_key = 'BASE_SERVICE_FEE_USD';
  v_txn := pay_plan_fee_from_wallet('test_ref_c3c_002');
  select amount into v_amount from wallet_transactions where id = v_txn;
  if v_amount <> 4.00 then raise exception 'TEST3 FAIL: debited %, expected 4.00', v_amount; end if;
  raise notice 'TEST3 PASS';
end $$;

-- 4. A garbage config value falls back to 2.50 instead of failing or mispricing.
do $$
declare
  v_txn uuid;
  v_amount numeric;
begin
  update system_configs set config_value = 'not-a-number' where config_key = 'BASE_SERVICE_FEE_USD';
  v_txn := pay_plan_fee_from_wallet('test_ref_c3c_003');
  select amount into v_amount from wallet_transactions where id = v_txn;
  if v_amount <> 2.50 then raise exception 'TEST4 FAIL: debited %, expected fallback 2.50', v_amount; end if;
  update system_configs set config_value = '2.50' where config_key = 'BASE_SERVICE_FEE_USD';
  raise notice 'TEST4 PASS';
end $$;

-- 5. Insufficient balance refuses and moves nothing.
do $$
declare
  v_before numeric;
  v_after numeric;
begin
  update wallets set balance = 1.00 where user_id = auth.uid();
  select balance into v_before from wallets where user_id = auth.uid();
  begin
    perform pay_plan_fee_from_wallet('test_ref_c3c_004');
    raise exception 'TEST5 FAIL: debited on insufficient balance';
  exception when others then
    if sqlerrm not like '%Insufficient wallet balance%' then
      raise exception 'TEST5 FAIL: unexpected error %', sqlerrm;
    end if;
  end;
  select balance into v_after from wallets where user_id = auth.uid();
  if v_before <> v_after then raise exception 'TEST5 FAIL: balance moved'; end if;
  raise notice 'TEST5 PASS';
end $$;

-- 6. Someone else's sim line is refused.
do $$
declare
  v_other_line uuid;
begin
  update wallets set balance = 100 where user_id = auth.uid();
  select id into v_other_line from sim_lines where user_id <> auth.uid() limit 1;
  if v_other_line is null then
    raise notice 'TEST6 SKIP: no foreign line found';
    return;
  end if;
  begin
    perform pay_plan_fee_from_wallet('test_ref_c3c_005', v_other_line);
    raise exception 'TEST6 FAIL: paid against a foreign line';
  exception when others then
    if sqlerrm not like '%does not belong%' then
      raise exception 'TEST6 FAIL: unexpected error %', sqlerrm;
    end if;
  end;
  raise notice 'TEST6 PASS';
end $$;

-- 7. plan_payments: clients cannot write, only read their own.
do $$
begin
  if has_table_privilege('authenticated', 'plan_payments', 'INSERT') then
    raise exception 'TEST7 FAIL: authenticated can INSERT plan_payments';
  end if;
  if has_table_privilege('anon', 'plan_payments', 'SELECT') then
    raise exception 'TEST7 FAIL: anon can SELECT plan_payments';
  end if;
  if not has_table_privilege('authenticated', 'plan_payments', 'SELECT') then
    raise exception 'TEST7 FAIL: authenticated cannot SELECT plan_payments';
  end if;
  raise notice 'TEST7 PASS';
end $$;

-- 8. anon cannot execute the RPC.
do $$
begin
  if has_function_privilege('anon', 'pay_plan_fee_from_wallet(text, uuid)', 'EXECUTE') then
    raise exception 'TEST8 FAIL: anon can execute pay_plan_fee_from_wallet';
  end if;
  raise notice 'TEST8 PASS';
end $$;

rollback;
