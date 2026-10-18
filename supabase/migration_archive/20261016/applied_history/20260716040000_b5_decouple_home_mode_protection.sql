-- B5: decouple "user is in this SIM's country" (is_home_mode) from "pause
-- protection" (protection_paused). A resident's dormant second SIM used to be
-- permanently home -> permanently unprotected -> shown healthy while it died.
-- Applied to live 2026-07-16.
ALTER TABLE public.sim_lines
  ADD COLUMN IF NOT EXISTS protection_paused boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS requires_protection_at_home boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.sim_lines.is_home_mode IS
  'Location fact only: the user is in this SIM''s home country. Does NOT pause protection by itself (B5).';
COMMENT ON COLUMN public.sim_lines.protection_paused IS
  'Intent: auto-refill protection is paused. Set when entering home mode unless requires_protection_at_home.';
COMMENT ON COLUMN public.sim_lines.requires_protection_at_home IS
  'This line must stay protected even while the user is home (e.g. a resident''s dormant second SIM).';

-- Backfill: every line currently in home mode was implicitly unprotected.
UPDATE public.sim_lines SET protection_paused = true WHERE is_home_mode;
