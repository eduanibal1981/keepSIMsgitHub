-- Migration: 20260914050000_retire_modes_and_unpause_lines.sql
-- Reset obsolete is_home_mode and protection_paused on sim lines.
-- "Modes" (Home Mode / Location-based protection pause) is obsolete.
-- All active lines remain protected regardless of country location.

UPDATE public.sim_lines
SET is_home_mode = false,
    protection_paused = false
WHERE is_home_mode = true OR protection_paused = true;

-- Default future lines to false
ALTER TABLE public.sim_lines ALTER COLUMN is_home_mode SET DEFAULT false;
ALTER TABLE public.sim_lines ALTER COLUMN protection_paused SET DEFAULT false;

-- Re-calculate health score for all lines using canonical 4-pillar function
UPDATE public.sim_lines sl
SET health_score = public.calculate_health_score(sl.id, sl.status, sl.last_topup_at);
