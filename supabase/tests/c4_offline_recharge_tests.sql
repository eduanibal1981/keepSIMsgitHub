-- C4 offline-recharge tests — run LIVE inside BEGIN..ROLLBACK via MCP
-- execute_sql (safe: nothing commits; workers cannot see uncommitted rows).
--
-- Verifies the offline ingestion path: per-channel message fees folded into the
-- wallet debit by calculate_topup_fees, the ingest_offline_refill RPC (happy
-- FIXED + RANGE, dedupe, unknown sender, disabled, no-target), the
-- service_role-only lockdown of the RPC + offline_refill_events, and that a
-- normal (NULL-channel) refill is unchanged.
--
-- Rate-limit note (same as c3b2): check_topup_rate_limit rejects a second
-- refill_instant per line inside 10s, and now() is frozen in one transaction —
-- so each queuing test uses a DIFFERENT a1 fixture line.

begin;

-- a1-wallet-test fixture: Vodafone EG (RANGE), Etisalat EG (FIXED 0.25), Zong PK
-- (RANGE). Give it a phone + offline settings for the whole suite.
update public.profiles set phone = '+201099998888'
  where email = 'a1-wallet-test@example.com';

insert into public.offline_refill_settings (user_id, is_enabled, default_refill_amount, target_sim_line_id)
values (
  (select id from public.profiles where email = 'a1-wallet-test@example.com'),
  true, 10.00, null
);

-- 1. The three per-channel fee configs exist and parse as numbers.
do $$
declare v_n int;
begin
  select count(*) into v_n from public.system_configs
  where config_key in ('OFFLINE_WHATSAPP_MESSAGE_FEE_USD',
                       'OFFLINE_SMS_MESSAGE_FEE_USD',
                       'OFFLINE_MISSED_CALL_FEE_USD')
    and config_value::numeric >= 0;
  if v_n <> 3 then
    raise exception 'TEST1 FAIL: expected 3 numeric fee configs, got %', v_n;
  end if;
  raise notice 'TEST1 PASS';
end $$;

-- 2. topup_executions gained refill_channel (checked) + message_fee_usd.
do $$
begin
  perform 1 from information_schema.columns
    where table_name = 'topup_executions'
      and column_name in ('refill_channel', 'message_fee_usd')
    having count(*) = 2;
  if not found then
    raise exception 'TEST2 FAIL: refill_channel / message_fee_usd missing';
  end if;
  begin
    -- invalid channel must be rejected by the CHECK constraint
    insert into public.topup_executions
      (sim_line_id, user_id, amount, base_cost_usd, status, execution_type, refill_channel)
    values ((select id from public.sim_lines where user_id =
             (select id from public.profiles where email='a1-wallet-test@example.com') limit 1),
            (select id from public.profiles where email='a1-wallet-test@example.com'),
            1, 1, 'pending', 'refill_instant', 'carrier_pigeon');
    raise exception 'TEST2 FAIL: bad refill_channel was accepted';
  exception when check_violation then
    raise notice 'TEST2 PASS';
  end;
end $$;

-- 3. no_target: 3 active lines, no target set ⇒ ambiguous ⇒ rejected.
do $$
declare v jsonb;
begin
  v := public.ingest_offline_refill('whatsapp','c4t3','+201099998888','whatsapp',null,'{}');
  if v->>'status' <> 'rejected' or v->>'reason' <> 'no_target' then
    raise exception 'TEST3 FAIL: expected no_target, got %', v;
  end if;
  raise notice 'TEST3 PASS';
end $$;

-- 4. FIXED happy path (Etisalat EG, whatsapp): amount = 0.25 base + 0.01 app
--    fee (3%) + 0.05 WhatsApp message fee = 0.31, wallet gateway, routing.
do $$
declare v jsonb; e record;
begin
  update public.offline_refill_settings
    set target_sim_line_id = '547dfbdf-b932-47b5-ab57-c20693ac272e'
    where user_id = (select id from public.profiles where email='a1-wallet-test@example.com');

  v := public.ingest_offline_refill('whatsapp','c4t4','+20 10 9999 8888','whatsapp',null,'{}');
  if v->>'status' <> 'queued' then
    raise exception 'TEST4 FAIL: expected queued, got %', v;
  end if;
  select amount, base_cost_usd, app_fee_usd, message_fee_usd, gateway_fee_usd,
         refill_channel, payment_gateway_code, status
  into e from public.topup_executions where id = (v->>'execution_id')::uuid;
  if e.amount <> 0.31 or e.base_cost_usd <> 0.25 or e.app_fee_usd <> 0.01
     or e.message_fee_usd <> 0.05 or e.gateway_fee_usd <> 0
     or e.refill_channel <> 'whatsapp' or e.payment_gateway_code <> 'wallet'
     or e.status <> 'routing' then
    raise exception 'TEST4 FAIL: unexpected execution %', row_to_json(e);
  end if;
  raise notice 'TEST4 PASS';
end $$;

-- 5. Dedupe: replaying the same (provider, provider_msg_id) returns duplicate,
--    does not queue a second refill.
do $$
declare v jsonb; v_before int; v_after int;
begin
  select count(*) into v_before from public.topup_executions
    where refill_channel = 'whatsapp';
  v := public.ingest_offline_refill('whatsapp','c4t4','+201099998888','whatsapp',null,'{}');
  select count(*) into v_after from public.topup_executions
    where refill_channel = 'whatsapp';
  if v->>'status' <> 'duplicate' or v_after <> v_before then
    raise exception 'TEST5 FAIL: expected duplicate/no-insert, got % (% -> %)', v, v_before, v_after;
  end if;
  raise notice 'TEST5 PASS';
end $$;

-- 6. RANGE (Vodafone EG, sms): default 10 clamps to the offer max, SMS fee 0.03.
do $$
declare v jsonb; e record;
begin
  update public.offline_refill_settings
    set target_sim_line_id = '42526fe7-560c-4f1a-9661-d34395dad041'
    where user_id = (select id from public.profiles where email='a1-wallet-test@example.com');

  v := public.ingest_offline_refill('sms','c4t6','+201099998888','sms',null,'{}');
  if v->>'status' <> 'queued' then
    raise exception 'TEST6 FAIL: expected queued, got %', v;
  end if;
  select amount, base_cost_usd, message_fee_usd, offer_value, refill_channel
  into e from public.topup_executions where id = (v->>'execution_id')::uuid;
  if e.message_fee_usd <> 0.03 or e.refill_channel <> 'sms'
     or e.base_cost_usd <= 0 or e.offer_value is null
     or e.amount <> round(e.base_cost_usd + round(e.base_cost_usd*0.03,2) + 0.03, 2) then
    raise exception 'TEST6 FAIL: unexpected execution %', row_to_json(e);
  end if;
  raise notice 'TEST6 PASS';
end $$;

-- 7. Disabled offline settings ⇒ rejected.
do $$
declare v jsonb;
begin
  update public.offline_refill_settings set is_enabled = false
    where user_id = (select id from public.profiles where email='a1-wallet-test@example.com');
  v := public.ingest_offline_refill('twilio','c4t7','+201099998888','missed_call',null,'{}');
  if v->>'status' <> 'rejected' or v->>'reason' <> 'disabled' then
    raise exception 'TEST7 FAIL: expected disabled, got %', v;
  end if;
  update public.offline_refill_settings set is_enabled = true
    where user_id = (select id from public.profiles where email='a1-wallet-test@example.com');
  raise notice 'TEST7 PASS';
end $$;

-- 8. Unknown sender ⇒ rejected, still audited.
do $$
declare v jsonb;
begin
  v := public.ingest_offline_refill('sms','c4t8','+19995550000','sms',null,'{}');
  if v->>'status' <> 'rejected' or v->>'reason' <> 'unknown_sender' then
    raise exception 'TEST8 FAIL: expected unknown_sender, got %', v;
  end if;
  if not exists (select 1 from public.offline_refill_events
                 where provider_msg_id = 'c4t8' and status = 'rejected') then
    raise exception 'TEST8 FAIL: rejection was not audited';
  end if;
  raise notice 'TEST8 PASS';
end $$;

-- 9. Lockdown: neither the RPC nor the event inbox is client-reachable.
do $$
begin
  if has_function_privilege('authenticated',
       'public.ingest_offline_refill(text,text,text,text,numeric,jsonb)', 'EXECUTE')
     or has_function_privilege('anon',
       'public.ingest_offline_refill(text,text,text,text,numeric,jsonb)', 'EXECUTE') then
    raise exception 'TEST9 FAIL: a client role can execute ingest_offline_refill';
  end if;
  if has_table_privilege('authenticated', 'public.offline_refill_events', 'SELECT')
     or has_table_privilege('anon', 'public.offline_refill_events', 'SELECT') then
    raise exception 'TEST9 FAIL: a client role can read offline_refill_events';
  end if;
  raise notice 'TEST9 PASS';
end $$;

-- 10. A normal (NULL-channel) wallet refill is unchanged: no message fee.
do $$
declare e record;
begin
  insert into public.topup_executions
    (sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code, currency,
     status, execution_type, refill_channel)
  values ('51a48fa0-ee06-4f91-8db4-1327c11599c1',  -- Zong PK, used nowhere else here
          (select id from public.profiles where email='a1-wallet-test@example.com'),
          5, 5, 'wallet', 'USD', 'pending', 'refill_instant', null)
  returning amount, app_fee_usd, message_fee_usd into e;
  -- base 5 + app fee 0.15 (3%) + no message fee = 5.15
  if e.message_fee_usd <> 0 or e.app_fee_usd <> 0.15 or e.amount <> 5.15 then
    raise exception 'TEST10 FAIL: NULL-channel refill mispriced %', row_to_json(e);
  end if;
  raise notice 'TEST10 PASS';
end $$;

-- Reached only if no assertion raised: every test above passed.
select 'ALL C4 TESTS PASSED' as result;

rollback;
