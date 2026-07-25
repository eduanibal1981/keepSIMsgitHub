-- C3b-2 lockdown tests — run LIVE inside BEGIN..ROLLBACK via MCP execute_sql
-- (safe: nothing commits; workers cannot see uncommitted rows).
--
-- Verifies the topup_executions client-write lockdown: revoked grants,
-- cancel_topup_execution, the schedule-delete cancel trigger, the
-- claim_due_executions parent guard, server-priced request_instant_refill
-- (FIXED + RANGE + staleness + wrong-catalog), update_mini_refill_dates,
-- retry_topup_execution, queue_premium_refill_executions, and the
-- refill_custom queue trigger.
--
-- Rate-limit note: check_topup_rate_limit rejects a second refill_instant
-- insert per line inside 10s, and in one transaction now() is frozen — so each
-- test that makes the RPC insert a refill_instant row uses a DIFFERENT fixture
-- line, and directly-inserted rows are backdated.

begin;

-- Impersonate the a1-wallet-test fixture (auth.uid() reads the JWT claims).
select set_config('request.jwt.claims',
  '{"sub":"e5a56433-6f75-41a3-96b9-19c62b9d1280","role":"authenticated"}', true);

-- 1. The grants are really gone: no client role can write the table; reads stay.
do $$
begin
  if has_table_privilege('authenticated', 'public.topup_executions', 'INSERT')
     or has_table_privilege('authenticated', 'public.topup_executions', 'UPDATE')
     or has_table_privilege('authenticated', 'public.topup_executions', 'DELETE')
     or has_table_privilege('authenticated', 'public.topup_executions', 'TRUNCATE') then
    raise exception 'TEST1 FAIL: authenticated still holds a write grant';
  end if;
  if has_table_privilege('anon', 'public.topup_executions', 'INSERT')
     or has_table_privilege('anon', 'public.topup_executions', 'UPDATE')
     or has_table_privilege('anon', 'public.topup_executions', 'DELETE')
     or has_table_privilege('anon', 'public.topup_executions', 'TRUNCATE') then
    raise exception 'TEST1 FAIL: anon still holds a write grant';
  end if;
  if not has_table_privilege('authenticated', 'public.topup_executions', 'SELECT') then
    raise exception 'TEST1 FAIL: authenticated lost SELECT';
  end if;
  if exists (select 1 from pg_policy
             where polrelid = 'public.topup_executions'::regclass
               and polcmd in ('a', 'w', 'd')) then
    raise exception 'TEST1 FAIL: a write policy still exists';
  end if;
  raise notice 'TEST1 PASS';
end $$;

-- 2. cancel_topup_execution cancels own queued work; terminal rows refuse.
do $$
declare
  v_line uuid;
  v_exec uuid;
begin
  select id into v_line from sim_lines where user_id = auth.uid() limit 1;
  insert into topup_executions
    (sim_line_id, user_id, amount, currency, status, execution_type,
     execution_time, created_at)
  values (v_line, auth.uid(), 5.00, 'USD', 'pending', 'refill_mini',
          now() + interval '1 day', now() - interval '1 minute')
  returning id into v_exec;

  if not cancel_topup_execution(v_exec) then
    raise exception 'TEST2 FAIL: cancel of a pending row returned false';
  end if;
  if (select status from topup_executions where id = v_exec) <> 'cancelled' then
    raise exception 'TEST2 FAIL: row is not cancelled';
  end if;
  -- Already cancelled ⇒ not queued any more ⇒ false, not an error.
  if cancel_topup_execution(v_exec) then
    raise exception 'TEST2 FAIL: cancelling a cancelled row returned true';
  end if;
  raise notice 'TEST2 PASS';
end $$;

-- 3. cancel_topup_execution refuses someone else's execution.
do $$
declare
  v_other uuid;
  v_other_line uuid;
  v_exec uuid;
begin
  select p.id into v_other from profiles p where p.id <> auth.uid() limit 1;
  select id into v_other_line from sim_lines where user_id = v_other limit 1;
  if v_other_line is null then
    -- No second user with a line in this environment; skip rather than fake it.
    raise notice 'TEST3 SKIP: no other user with a sim line';
    return;
  end if;
  insert into topup_executions
    (sim_line_id, user_id, amount, currency, status, execution_type,
     execution_time, created_at)
  values (v_other_line, v_other, 5.00, 'USD', 'pending', 'refill_mini',
          now() + interval '1 day', now() - interval '1 minute')
  returning id into v_exec;
  begin
    perform cancel_topup_execution(v_exec);
    raise exception 'TEST3 FAIL: cancelled another user''s execution';
  exception when others then
    if sqlerrm not like '%Not authorized%' then raise; end if;
  end;
  raise notice 'TEST3 PASS';
end $$;

-- 4. Deleting a schedule cancels its queued executions (the orphan bug).
do $$
declare
  v_line uuid;
  v_sched uuid;
  v_exec uuid;
begin
  select id into v_line from sim_lines where user_id = auth.uid() limit 1;
  insert into scheduled_topups
    (sim_line_id, user_id, amount, currency, frequency_days, next_execution_at,
     is_active, status, schedule_type)
  values (v_line, auth.uid(), 5.00, 'USD', 30, now() + interval '1 day',
          true, 'active', 'refill_mini')
  returning id into v_sched;
  insert into topup_executions
    (sim_line_id, user_id, amount, currency, status, execution_type,
     execution_time, scheduled_topup_id, created_at)
  values (v_line, auth.uid(), 5.00, 'USD', 'pending', 'refill_mini',
          now() - interval '1 hour', v_sched, now() - interval '1 minute')
  returning id into v_exec;

  delete from scheduled_topups where id = v_sched;

  if (select status from topup_executions where id = v_exec) <> 'cancelled' then
    raise exception 'TEST4 FAIL: schedule delete left the execution %',
      (select status from topup_executions where id = v_exec);
  end if;
  raise notice 'TEST4 PASS';
end $$;

-- 5. claim_due_executions skips work whose parent schedule is paused, and
--    claims it once the schedule is active again.
do $$
declare
  v_line uuid;
  v_sched uuid;
  v_exec uuid;
begin
  select id into v_line from sim_lines where user_id = auth.uid() limit 1;
  insert into scheduled_topups
    (sim_line_id, user_id, amount, currency, frequency_days, next_execution_at,
     is_active, status, schedule_type)
  values (v_line, auth.uid(), 5.00, 'USD', 30, now() - interval '1 hour',
          false, 'paused', 'refill_mini')
  returning id into v_sched;
  insert into topup_executions
    (sim_line_id, user_id, amount, currency, status, execution_type,
     execution_time, scheduled_topup_id, created_at)
  values (v_line, auth.uid(), 5.00, 'USD', 'pending', 'refill_mini',
          now() - interval '1 hour', v_sched, now() - interval '1 minute')
  returning id into v_exec;

  if exists (select 1 from claim_due_executions('refill_mini', 100) c where c.id = v_exec) then
    raise exception 'TEST5 FAIL: claimed an execution whose schedule is paused';
  end if;

  update scheduled_topups set is_active = true, status = 'active' where id = v_sched;

  if not exists (select 1 from claim_due_executions('refill_mini', 100) c where c.id = v_exec) then
    raise exception 'TEST5 FAIL: did not claim after the schedule was resumed';
  end if;
  raise notice 'TEST5 PASS';
end $$;

-- 6. request_instant_refill prices a FIXED offer from the cache — the client
--    supplies no price at all, and the row routes for the worker.
do $$
declare
  v_line uuid;
  v_iso text;
  v_zen text;
  v_exec uuid;
  r record;
begin
  select sl.id, co.iso_code, ca.zen_carrier into v_line, v_iso, v_zen
  from sim_lines sl
  join countries co on co.id = sl.country_id
  join carriers ca on ca.id = sl.carrier_id
  where sl.user_id = auth.uid() and ca.zen_carrier is not null
  order by sl.created_at limit 1;

  insert into zendit_offers_cache
    (offer_id, country_code, zen_carrier, offer_name, price_type, price_fixed_usd)
  values ('TEST_C3B2_FIXED', v_iso, v_zen, 'C3b-2 fixed test', 'FIXED', 6.25);

  v_exec := request_instant_refill(v_line, 'TEST_C3B2_FIXED', 'wallet', null);

  select * into r from topup_executions where id = v_exec;
  if r.base_cost_usd <> 6.25 then
    raise exception 'TEST6 FAIL: base_cost_usd is %, expected the cache price 6.25', r.base_cost_usd;
  end if;
  if r.status <> 'routing' then
    raise exception 'TEST6 FAIL: status is %, expected routing', r.status;
  end if;
  if r.user_id <> auth.uid() or r.execution_type <> 'refill_instant' then
    raise exception 'TEST6 FAIL: wrong user or execution_type';
  end if;
  -- calculate_topup_fees ran: amount = base + gateway fee + app fee.
  if r.amount < r.base_cost_usd then
    raise exception 'TEST6 FAIL: amount % below base cost', r.amount;
  end if;
  raise notice 'TEST6 PASS';
end $$;

-- 7. RANGE offers: the USD amount must sit in the range and the send value is
--    interpolated server-side; out-of-range refuses.
do $$
declare
  v_line uuid;
  v_iso text;
  v_zen text;
  v_exec uuid;
  v_value numeric;
begin
  -- Second line, so the instant-refill rate limit doesn't trip.
  select sl.id, co.iso_code, ca.zen_carrier into v_line, v_iso, v_zen
  from sim_lines sl
  join countries co on co.id = sl.country_id
  join carriers ca on ca.id = sl.carrier_id
  where sl.user_id = auth.uid() and ca.zen_carrier is not null
  order by sl.created_at offset 1 limit 1;

  insert into zendit_offers_cache
    (offer_id, country_code, zen_carrier, offer_name, price_type,
     price_min_usd, price_max_usd, send_min, send_max, send_currency_divisor)
  values ('TEST_C3B2_RANGE', v_iso, v_zen, 'C3b-2 range test', 'RANGE',
          1, 50, 800, 20000, 100);

  v_exec := request_instant_refill(v_line, 'TEST_C3B2_RANGE', 'wallet', 10.00);
  select offer_value into v_value from topup_executions where id = v_exec;
  -- 800 + (10-1)/(50-1) * (20000-800) = 4326.53… → 4327
  if v_value <> 4327 then
    raise exception 'TEST7 FAIL: offer_value %, expected interpolated 4327', v_value;
  end if;
  if (select base_cost_usd from topup_executions where id = v_exec) <> 10.00 then
    raise exception 'TEST7 FAIL: base_cost_usd not the requested 10.00';
  end if;

  begin
    perform request_instant_refill(v_line, 'TEST_C3B2_RANGE', 'wallet', 0.50);
    raise exception 'TEST7 FAIL: accepted an amount below the range';
  exception when others then
    if sqlerrm not like '%outside%' then raise; end if;
  end;
  raise notice 'TEST7 PASS';
end $$;

-- 8. A stale cache row refuses to price; an offer from another catalog refuses.
do $$
declare
  v_line uuid;
  v_iso text;
  v_zen text;
begin
  select sl.id, co.iso_code, ca.zen_carrier into v_line, v_iso, v_zen
  from sim_lines sl
  join countries co on co.id = sl.country_id
  join carriers ca on ca.id = sl.carrier_id
  where sl.user_id = auth.uid() and ca.zen_carrier is not null
  order by sl.created_at limit 1;

  insert into zendit_offers_cache
    (offer_id, country_code, zen_carrier, price_type, price_fixed_usd, refreshed_at)
  values ('TEST_C3B2_STALE', v_iso, v_zen, 'FIXED', 3.00, now() - interval '25 hours');
  begin
    perform request_instant_refill(v_line, 'TEST_C3B2_STALE', 'wallet', null);
    raise exception 'TEST8 FAIL: priced from a 25h-old cache row';
  exception when others then
    if sqlerrm not like '%temporarily unavailable%' then raise; end if;
  end;

  insert into zendit_offers_cache
    (offer_id, country_code, zen_carrier, price_type, price_fixed_usd)
  values ('TEST_C3B2_FOREIGN', 'ZZ', 'NotThisCarrier', 'FIXED', 0.01);
  begin
    perform request_instant_refill(v_line, 'TEST_C3B2_FOREIGN', 'wallet', null);
    raise exception 'TEST8 FAIL: bought an offer from another catalog';
  exception when others then
    if sqlerrm not like '%not available%' then raise; end if;
  end;
  raise notice 'TEST8 PASS';
end $$;

-- 9. update_mini_refill_dates moves only this line's own pending mini rows and
--    re-syncs the schedule.
do $$
declare
  v_line uuid;
  v_sched uuid;
  v_exec uuid;
  v_target timestamptz := date_trunc('minute', now() + interval '10 days');
  v_moved integer;
begin
  select id into v_line from sim_lines where user_id = auth.uid() limit 1;
  delete from scheduled_topups where sim_line_id = v_line;
  insert into scheduled_topups
    (sim_line_id, user_id, amount, currency, frequency_days, next_execution_at,
     is_active, status, schedule_type)
  values (v_line, auth.uid(), 5.00, 'USD', 30, now() + interval '30 days',
          true, 'active', 'refill_mini')
  returning id into v_sched;
  insert into topup_executions
    (sim_line_id, user_id, amount, currency, status, execution_type,
     execution_time, scheduled_topup_id, created_at)
  values (v_line, auth.uid(), 5.00, 'USD', 'pending', 'refill_mini',
          now() + interval '30 days', v_sched, now() - interval '1 minute')
  returning id into v_exec;

  -- One real row + one bogus id: the bogus one must be skipped, not fail.
  v_moved := update_mini_refill_dates(v_line, jsonb_build_object(
    v_exec::text, to_char(v_target, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    gen_random_uuid()::text, to_char(v_target, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')));

  if v_moved <> 1 then
    raise exception 'TEST9 FAIL: moved % rows, expected 1', v_moved;
  end if;
  if (select execution_time from topup_executions where id = v_exec) <> v_target then
    raise exception 'TEST9 FAIL: execution_time did not move';
  end if;
  if (select next_execution_at from scheduled_topups where id = v_sched) <> v_target then
    raise exception 'TEST9 FAIL: schedule next_execution_at not re-synced';
  end if;
  raise notice 'TEST9 PASS';
end $$;

-- 10. retry_topup_execution queues a NEW execution through the pipeline and
--     refuses a second concurrent retry.
do $$
declare
  v_line uuid;
  v_fail uuid;
  v_retry uuid;
  r record;
begin
  -- A line with no in-transaction refill_instant rows: the retry inserts a
  -- refill_instant row and the rate limit is per line, so reusing a line from
  -- tests 6/7 would trip it.
  select sl.id into v_line
  from sim_lines sl
  where sl.user_id = auth.uid()
    and not exists (select 1 from topup_executions t
                    where t.sim_line_id = sl.id
                      and t.execution_type = 'refill_instant'
                      and t.created_at > now() - interval '10 seconds')
  order by sl.created_at limit 1;

  insert into topup_executions
    (sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code,
     currency, status, execution_type, execution_time, failure_reason, created_at)
  values (v_line, auth.uid(), 5.15, 5.00, 'wallet', 'USD', 'failed',
          'refill_instant', now() - interval '1 hour', 'test failure',
          now() - interval '1 minute')
  returning id into v_fail;

  v_retry := retry_topup_execution(v_fail);
  select * into r from topup_executions where id = v_retry;
  if r.retry_of <> v_fail then
    raise exception 'TEST10 FAIL: retry_of not linked';
  end if;
  if r.status <> 'routing' then
    raise exception 'TEST10 FAIL: retry status %, expected routing', r.status;
  end if;
  if r.base_cost_usd <> 5.00 then
    raise exception 'TEST10 FAIL: retry base_cost_usd %, expected 5.00', r.base_cost_usd;
  end if;
  if (select status from topup_executions where id = v_fail) <> 'failed' then
    raise exception 'TEST10 FAIL: original changed status (the old mock flow relabelled it refunded)';
  end if;

  begin
    perform retry_topup_execution(v_fail);
    raise exception 'TEST10 FAIL: allowed a second concurrent retry';
  exception when others then
    if sqlerrm not like '%already has a retry%' then raise; end if;
  end;
  raise notice 'TEST10 PASS';
end $$;

-- 11. queue_premium_refill_executions prices the plan year from carrier_rules
--     and is idempotent per schedule.
do $$
declare
  v_line uuid;
  v_sched uuid;
  v_rule record;
  v_count integer;
  v_count2 integer;
  v_expected integer;
begin
  select sl.id into v_line
  from sim_lines sl
  join carrier_rules cr on cr.id = sl.carrier_rule_id
  where sl.user_id = auth.uid() and cr.minimum_topup_amount > 0
  limit 1;
  if v_line is null then
    raise notice 'TEST11 SKIP: fixture has no line with a carrier rule';
    return;
  end if;
  select cr.* into v_rule from sim_lines sl
  join carrier_rules cr on cr.id = sl.carrier_rule_id where sl.id = v_line;

  delete from scheduled_topups where sim_line_id = v_line and schedule_type = 'refill_mini';
  insert into scheduled_topups
    (sim_line_id, user_id, amount, currency, frequency_days, next_execution_at,
     is_active, status, schedule_type)
  values (v_line, auth.uid(), v_rule.minimum_topup_amount, 'USD',
          v_rule.topup_validity_days, now() + interval '1 day',
          true, 'active', 'refill_mini')
  returning id into v_sched;

  v_count := queue_premium_refill_executions(
    v_line, v_sched, now() + interval '365 days', now());
  v_expected := ceil(365.0 / v_rule.topup_validity_days);
  if v_count <> v_expected then
    raise exception 'TEST11 FAIL: queued %, expected ceil(365/%) = %',
      v_count, v_rule.topup_validity_days, v_expected;
  end if;
  if exists (select 1 from topup_executions
             where scheduled_topup_id = v_sched and status = 'pending'
               and (amount <> v_rule.minimum_topup_amount
                    or payment_gateway_code is not null)) then
    raise exception 'TEST11 FAIL: a queued row is mispriced or carries a gateway';
  end if;

  -- Re-run: same count, and no doubled queue.
  v_count2 := queue_premium_refill_executions(
    v_line, v_sched, now() + interval '365 days', now());
  if v_count2 <> v_count then
    raise exception 'TEST11 FAIL: requeue count % differs', v_count2;
  end if;
  if (select count(*) from topup_executions
      where scheduled_topup_id = v_sched and status = 'pending') <> v_count then
    raise exception 'TEST11 FAIL: requeue doubled the pending queue';
  end if;
  raise notice 'TEST11 PASS';
end $$;

-- 12. The refill_custom queue follows its schedule row: created on insert,
--     rebuilt on change, cancelled on pause.
do $$
declare
  v_line uuid;
  v_sched uuid;
  v_exec uuid;
begin
  select id into v_line from sim_lines where user_id = auth.uid() limit 1;

  insert into scheduled_topups
    (sim_line_id, user_id, amount, currency, frequency_days, next_execution_at,
     is_active, status, schedule_type)
  values (v_line, auth.uid(), 7.00, 'USD', 30, now() + interval '3 days',
          true, 'active', 'refill_custom')
  returning id into v_sched;

  select id into v_exec from topup_executions
  where scheduled_topup_id = v_sched and status = 'pending';
  if v_exec is null then
    raise exception 'TEST12 FAIL: creating an active custom schedule queued nothing';
  end if;

  update scheduled_topups set amount = 9.00 where id = v_sched;
  if (select status from topup_executions where id = v_exec) <> 'cancelled' then
    raise exception 'TEST12 FAIL: amount change did not cancel the old queue';
  end if;
  if not exists (select 1 from topup_executions
                 where scheduled_topup_id = v_sched and status = 'pending'
                   and amount = 9.00) then
    raise exception 'TEST12 FAIL: amount change did not requeue at the new amount';
  end if;

  update scheduled_topups set is_active = false where id = v_sched;
  if exists (select 1 from topup_executions
             where scheduled_topup_id = v_sched and status = 'pending') then
    raise exception 'TEST12 FAIL: pausing left a pending execution';
  end if;
  raise notice 'TEST12 PASS';
end $$;

select 'ALL C3B2 TESTS PASSED' as result;

rollback;
