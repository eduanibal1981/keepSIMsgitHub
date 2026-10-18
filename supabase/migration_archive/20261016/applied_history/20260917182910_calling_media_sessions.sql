-- Only the server can read or consume a short-lived app audio session.
create table if not exists public.call_media_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  credential_id text not null,
  sip_username text not null,
  expires_at timestamptz not null,
  call_record_id uuid unique references public.call_records(id) on delete cascade,
  app_answered boolean not null default false,
  media_ready boolean not null default false,
  dial_started boolean not null default false,
  cleaned_up boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.call_media_sessions enable row level security;
revoke all on public.call_media_sessions from anon, authenticated;
grant all on public.call_media_sessions to service_role;
create index if not exists call_media_sessions_user on public.call_media_sessions(user_id, created_at);
create index if not exists call_media_sessions_cleanup on public.call_media_sessions(expires_at) where cleaned_up = false;

-- Ensure 'declined' is allowed by call_records.status check constraint
alter table public.call_records drop constraint if exists call_records_status_check;
alter table public.call_records add constraint call_records_status_check
  check (status in ('initiated', 'ringing', 'in_progress', 'completed', 'declined', 'busy', 'failed', 'no_answer', 'cancelled'));

-- Durable webhook deduplication table
create table if not exists public.processed_webhook_events (
  event_id text primary key,
  event_type text not null,
  call_record_id uuid references public.call_records(id) on delete cascade,
  processed_at timestamptz not null default now()
);
alter table public.processed_webhook_events enable row level security;
revoke all on public.processed_webhook_events from anon, authenticated;
grant all on public.processed_webhook_events to service_role;
create index if not exists idx_processed_webhook_events_date on public.processed_webhook_events(processed_at);

-- Serialize the two legs' terminal webhooks and commit the charge with the result.
create or replace function public.finish_media_call(p_call_id uuid, p_ended_at timestamptz,
  p_status text, p_error text, p_payload jsonb)
returns void language plpgsql security invoker set search_path = '' as $$
declare
  r public.call_records%rowtype;
  seconds integer := 0;
  cost numeric := 0;
begin
  select * into r from public.call_records where id = p_call_id for update;
  if not found or r.call_type <> 'app_to_phone_webrtc' then return; end if;
  if r.status in ('completed','declined','busy','no_answer','cancelled','failed') then return; end if;
  if r.answered_at is not null then
    seconds := greatest(0, ceil(extract(epoch from (p_ended_at - r.answered_at)))::integer);
    cost := round(seconds * r.rate_per_minute_usd / 60, 4);
    if cost > 0 then
      perform public.debit_wallet_for_call(r.user_id, r.id, cost, 'International call');
    end if;
  end if;
  update public.call_records set
    status = case when r.answered_at is not null then 'completed' else p_status end,
    ended_at = p_ended_at, duration_seconds = seconds, billed_duration_seconds = seconds,
    total_cost_usd = cost, error_message = p_error, raw_cdr = p_payload,
    telnyx_hangup_cause = p_payload->>'hangup_cause', hangup_source = p_payload->>'hangup_source'
  where id = r.id;
end;
$$;
revoke all on function public.finish_media_call(uuid,timestamptz,text,text,jsonb) from public, anon, authenticated;
grant execute on function public.finish_media_call(uuid,timestamptz,text,text,jsonb) to service_role;
