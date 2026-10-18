-- ============================================================================
-- Selective Foreign Key Covering Indexes
--
-- Adds supporting btree indexes for high-churn foreign key columns used in:
--   1. Account deletion cascading (user_id cascades)
--   2. SIM line deletion and line timeline queries (sim_line_id)
--   3. Execution retry tracking (retry_of)
-- ============================================================================

-- 1. High-churn foreign keys used in account-deletion cascading and user reporting
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id 
  ON public.analytics_events(user_id);

CREATE INDEX IF NOT EXISTS idx_campaign_deliveries_user_id 
  ON public.campaign_deliveries(user_id);

CREATE INDEX IF NOT EXISTS idx_offline_voucher_requests_user_id 
  ON public.offline_voucher_requests(user_id);

CREATE INDEX IF NOT EXISTS idx_user_esims_user_id 
  ON public.user_esims(user_id);

CREATE INDEX IF NOT EXISTS idx_ticket_messages_user_id 
  ON public.ticket_messages(user_id);

-- 2. SIM line foreign keys used in line activity reporting and line deletion cleanup
CREATE INDEX IF NOT EXISTS idx_call_records_sim_line_id 
  ON public.call_records(sim_line_id);

CREATE INDEX IF NOT EXISTS idx_notifications_sim_line_id 
  ON public.notifications(sim_line_id);

CREATE INDEX IF NOT EXISTS idx_support_tickets_sim_line_id 
  ON public.support_tickets(sim_line_id);

CREATE INDEX IF NOT EXISTS idx_offline_refill_events_sim_line_id 
  ON public.offline_refill_events(sim_line_id);

-- 3. Execution retry tracking
CREATE INDEX IF NOT EXISTS idx_topup_executions_retry_of 
  ON public.topup_executions(retry_of) 
  WHERE retry_of IS NOT NULL;
