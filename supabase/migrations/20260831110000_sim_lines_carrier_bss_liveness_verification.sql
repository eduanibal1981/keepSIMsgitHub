-- 20260831110000_sim_lines_carrier_bss_liveness_verification.sql
-- Adds automated carrier BSS liveness and activity verification columns to sim_lines table.

ALTER TABLE public.sim_lines
  ADD COLUMN IF NOT EXISTS is_carrier_verified BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS carrier_status TEXT DEFAULT 'pending' 
    CHECK (carrier_status IN ('pending', 'active', 'inactive', 'unsupported')),
  ADD COLUMN IF NOT EXISTS detected_operator_name TEXT,
  ADD COLUMN IF NOT EXISTS carrier_verified_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_sim_lines_carrier_status ON public.sim_lines(carrier_status);
