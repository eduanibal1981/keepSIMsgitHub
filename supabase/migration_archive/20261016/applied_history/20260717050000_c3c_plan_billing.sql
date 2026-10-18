-- C3c: payments & fees — one source of truth (owner's instruction 2026-07-17).
--
-- 1. BASE_SERVICE_FEE_USD and the offline contact numbers become system_configs
--    rows: every price the app shows or charges is a DB value, changeable with
--    no app update.
-- 2. pay_plan_fee_from_wallet(): the yearly Standard service fee, billed
--    wallet-first (owner's decision — PayPal's $0.49 fixed fee eats 23% of a
--    standalone $2.50 charge; the wallet gateway costs 0% + $0.00). The price
--    is read server-side from system_configs, never taken from the client.
-- 3. plan_payments: plan charges billed through PayPal (custom_id kind 'plan')
--    get recorded here by the paypal-webhook. Until now every plan charge was
--    tagged kind 'deposit', so the webhook credited the full charge back into
--    the payer's wallet — paid plans were effectively free.

-- ── 1. Config rows ───────────────────────────────────────────────────────────
insert into public.system_configs (config_key, config_value)
values
  ('BASE_SERVICE_FEE_USD', '2.50'),
  ('OFFLINE_IVR_NUMBER', '+968 24 555 0111'),
  ('OFFLINE_SMS_NUMBER', '+968 24 555 0112'),
  ('OFFLINE_WHATSAPP_NUMBER', '+968 24 555 0113')
on conflict (config_key) do nothing;

-- ── 2. Wallet-billed plan fee ────────────────────────────────────────────────
alter table public.wallet_transactions
  drop constraint wallet_transactions_type_check;
alter table public.wallet_transactions
  add constraint wallet_transactions_type_check
  check (type = any (array[
    'deposit', 'topup_debit', 'refund', 'referral_credit',
    'welcome_home_debit', 'auto_fund', 'plan_fee_debit'
  ]::text[]));

-- Same idempotency pattern as topup_debit/refund (B1): one debit per reference.
create unique index if not exists uq_wallet_transactions_plan_fee_ref
  on public.wallet_transactions (reference_id)
  where type = 'plan_fee_debit' and reference_id is not null;

create or replace function public.pay_plan_fee_from_wallet(
  p_reference_id text,
  p_sim_line_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_user uuid := auth.uid();
  v_fee numeric;
  v_wallet_id uuid;
  v_balance_before numeric;
  v_balance_after numeric;
  v_txn_id uuid;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;
  if p_reference_id is null or length(trim(p_reference_id)) < 8 then
    raise exception 'A reference id of at least 8 characters is required';
  end if;

  -- A supplied line must be the caller's own; the fee itself is per line.
  if p_sim_line_id is not null and not exists (
    select 1 from public.sim_lines
    where id = p_sim_line_id and user_id = v_user
  ) then
    raise exception 'SIM line % does not belong to the caller', p_sim_line_id;
  end if;

  -- The price comes from the DB, never from the client. Same guard style as
  -- calculate_topup_fees: a garbage or missing row falls back instead of
  -- billing nonsense.
  begin
    select config_value::numeric into v_fee
    from public.system_configs
    where config_key = 'BASE_SERVICE_FEE_USD';
  exception when others then
    v_fee := null;
  end;
  if v_fee is null or v_fee <= 0 or v_fee > 1000 then
    v_fee := 2.50;
  end if;

  select id, balance into v_wallet_id, v_balance_before
  from public.wallets
  where user_id = v_user
  for update;

  if v_wallet_id is null then
    raise exception 'Wallet not found for user %', v_user;
  end if;

  -- Retry-safe: checked after the wallet lock so concurrent retries serialize
  -- on the row and the second caller adopts the first one's debit.
  select id into v_txn_id
  from public.wallet_transactions
  where type = 'plan_fee_debit' and reference_id = p_reference_id;
  if v_txn_id is not null then
    return v_txn_id;
  end if;

  if v_balance_before < v_fee then
    raise exception 'Insufficient wallet balance. Have: %, Need: %',
      v_balance_before, v_fee;
  end if;

  v_balance_after := v_balance_before - v_fee;

  update public.wallets
  set balance = v_balance_after,
      total_spent = total_spent + v_fee
  where id = v_wallet_id;

  insert into public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, sim_line_id, status
  ) values (
    v_wallet_id, v_user, 'plan_fee_debit', v_fee, v_balance_before,
    v_balance_after, 'Yearly plan service fee', p_reference_id,
    p_sim_line_id, 'completed'
  ) returning id into v_txn_id;

  return v_txn_id;
end;
$$;

revoke all on function public.pay_plan_fee_from_wallet(text, uuid) from public, anon;
grant execute on function public.pay_plan_fee_from_wallet(text, uuid)
  to authenticated, service_role;

-- ── 3. PayPal-billed plan charges ────────────────────────────────────────────
create table public.plan_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  capture_id text not null unique,
  order_id text,
  kind text not null default 'plan',
  gross_usd numeric not null check (gross_usd > 0),
  paypal_fee_usd numeric,
  net_usd numeric,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index idx_plan_payments_user on public.plan_payments (user_id);

alter table public.plan_payments enable row level security;

-- Users can see their own payment history; only the webhook (service_role)
-- writes.
create policy plan_payments_select_own on public.plan_payments
  for select to authenticated using (auth.uid() = user_id);

revoke all on public.plan_payments from anon, authenticated;
grant select on public.plan_payments to authenticated;
