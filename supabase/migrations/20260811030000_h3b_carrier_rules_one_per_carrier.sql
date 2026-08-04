-- H3b — carrier_rules had no unique constraint on carrier_id, only a plain
-- index. Two consequences, one latent and one immediate:
--
--   * admin_list_carriers() LEFT JOINs the rule onto the carrier. A second rule
--     row for the same carrier would silently duplicate that carrier in the
--     admin list, and there would be no way to tell which of the two the
--     forecast engine is reading.
--   * admin_update_carrier_rule()'s upsert had no constraint to target and
--     would have raised 42P10 the first time it ran against the one carrier of
--     50 that has no rule row.
--
-- Verified clean before adding: 0 carrier_ids with more than one rule.
CREATE UNIQUE INDEX IF NOT EXISTS carrier_rules_carrier_id_key
  ON public.carrier_rules (carrier_id);

DROP INDEX IF EXISTS public.idx_carrier_rules_carrier_id;

COMMENT ON INDEX public.carrier_rules_carrier_id_key IS
  'H3b: one refill rule per carrier. The forecast engine, the rescue engine and the admin list all assume this; nothing enforced it until now.';
