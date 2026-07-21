-- DTone provider tests — run LIVE inside BEGIN..ROLLBACK via MCP execute_sql
-- (safe: nothing commits; workers cannot see uncommitted rows).

begin;

-- Impersonate fixture user a1-wallet-test
select set_config('request.jwt.claims',
  '{"sub":"e5a56433-6f75-41a3-96b9-19c62b9d1280","role":"authenticated"}', true);

-- 1. provider_offers_cache permissions and view compatibility
do $$
begin
  if not has_table_privilege('authenticated', 'public.provider_offers_cache', 'SELECT') then
    raise exception 'TEST1 FAIL: authenticated cannot read provider_offers_cache';
  end if;
  if has_table_privilege('authenticated', 'public.provider_offers_cache', 'INSERT')
     or has_table_privilege('authenticated', 'public.provider_offers_cache', 'UPDATE')
     or has_table_privilege('authenticated', 'public.provider_offers_cache', 'DELETE') then
    raise exception 'TEST1 FAIL: authenticated holds write privileges on provider_offers_cache';
  end if;
  if not has_table_privilege('authenticated', 'public.zendit_offers_cache', 'SELECT') then
    raise exception 'TEST1 FAIL: authenticated cannot read zendit_offers_cache view';
  end if;
  raise notice 'TEST1 PASS: permissions & view checked';
end $$;

-- 2. Insert DTone offer into provider_offers_cache and verify lookup
do $$
declare
  v_country_id uuid;
  v_carrier_id uuid;
  v_sim_line_id uuid;
  v_exec_id uuid;
  v_exec_provider text;
begin
  -- Get or create test carrier with DTone provider
  select id into v_country_id from countries where iso_code = 'US' limit 1;
  if v_country_id is null then
    insert into countries (name, iso_code) values ('United States', 'US') returning id into v_country_id;
  end if;

  insert into carriers (name, country_id, api_provider, dt_country, dt_carrier, is_supported)
  values ('Mint Mobile Test', v_country_id, 'dtone', 'USA', 'mint_mobile', true)
  returning id into v_carrier_id;

  -- Insert DTone offer in provider_offers_cache
  insert into provider_offers_cache (
    api_provider, offer_id, country_code, carrier_code, offer_name,
    price_type, price_fixed_usd, send_currency, send_currency_divisor, refreshed_at
  ) values (
    'dtone', 'dt_mint_10usd', 'US', 'mint_mobile', '$10 Mint Topup',
    'FIXED', 10.00, 'USD', 1, now()
  );

  -- Create a SIM line for user
  insert into sim_lines (user_id, country_id, carrier_id, phone_number, status)
  values ('e5a56433-6f75-41a3-96b9-19c62b9d1280', v_country_id, v_carrier_id, '+15550001111', 'active')
  returning id into v_sim_line_id;

  -- Test request_instant_refill for DTone offer
  v_exec_id := request_instant_refill(v_sim_line_id, 'dt_mint_10usd', 'wallet', null);

  if v_exec_id is null then
    raise exception 'TEST2 FAIL: request_instant_refill returned null';
  end if;

  select api_provider into v_exec_provider from topup_executions where id = v_exec_id;
  if v_exec_provider <> 'dtone' then
    raise exception 'TEST2 FAIL: topup_execution api_provider expected dtone, got %', v_exec_provider;
  end if;

  raise notice 'TEST2 PASS: DTone offer instant refill queued successfully (exec_id: %)', v_exec_id;
end $$;

rollback;
