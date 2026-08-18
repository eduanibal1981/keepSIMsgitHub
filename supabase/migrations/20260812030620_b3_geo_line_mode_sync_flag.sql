-- B3 follow-up: the geo → per-line home/travel sync the B3 code path always
-- documented and no code ever performed.
--
-- `detect-country` wrote `profiles.last_country` and posted a notification;
-- nothing ever touched `sim_lines.is_home_mode`. The only writers were two UI
-- switches, so a line kept whatever the user last tapped. Found live: a Saudi
-- (+966) line sitting in `is_home_mode = true, protection_paused = true` — and
-- therefore skipped by `run_auto_rescue` — while its owner was in Oman.
--
-- Ships OFF. Turning it on un-pauses protection for every line whose country
-- the user is not in, which resumes that line's `scheduled_topups` and makes it
-- eligible for auto-rescue spending. That is a live money decision and belongs
-- to the owner, not to a deploy.
--
--   UPDATE public.system_configs SET config_value = 'true'
--    WHERE config_key = 'GEO_LINE_MODE_SYNC_ENABLED';
--
-- With it on, the next app open reconciles every line against the detected
-- country; no data backfill is needed or performed here.

-- (system_configs is key/value only — no description column.)
INSERT INTO public.system_configs (config_key, config_value)
VALUES ('GEO_LINE_MODE_SYNC_ENABLED', 'false')
ON CONFLICT (config_key) DO NOTHING;
