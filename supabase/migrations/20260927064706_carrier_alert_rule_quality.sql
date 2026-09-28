-- Role-gated carrier-rule evidence and impact preview for the admin app.
CREATE OR REPLACE FUNCTION public.admin_get_carrier_alert_rule(p_carrier_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE v_rule record;
BEGIN
  PERFORM public.assert_admin();
  SELECT * INTO v_rule FROM public.carrier_rules
  WHERE carrier_id=p_carrier_id LIMIT 1;
  RETURN jsonb_build_object(
    'carrier_id',p_carrier_id,
    'activity_requirement',v_rule.activity_requirement,
    'validity_qualifying_topup_amount',v_rule.validity_qualifying_topup_amount,
    'activity_requirement_note',v_rule.activity_requirement_note,
    'rule_source_url',v_rule.rule_source_url,
    'last_verified_at',v_rule.last_verified_at,
    'inactivity_limit_days',v_rule.inactivity_limit_days,
    'grace_period_days',v_rule.grace_period_days,
    'topup_validity_days',v_rule.topup_validity_days,
    'balance_validity_days',v_rule.balance_validity_days,
    'active_lines',(SELECT count(*) FROM public.sim_lines
      WHERE carrier_id=p_carrier_id AND status='active')
  );
END;
$$;
REVOKE ALL ON FUNCTION public.admin_get_carrier_alert_rule(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_carrier_alert_rule(uuid)
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_preview_carrier_alert_rule(
  p_carrier_id uuid, p_patch jsonb
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE v_rule record; v_days integer; v_requirement text;
BEGIN
  PERFORM public.assert_admin();
  SELECT * INTO v_rule FROM public.carrier_rules
  WHERE carrier_id=p_carrier_id LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Carrier rule not found' USING ERRCODE='KS404'; END IF;
  v_days := COALESCE(NULLIF(p_patch->>'inactivity_limit_days','')::integer,
    v_rule.inactivity_limit_days);
  v_requirement := COALESCE(NULLIF(p_patch->>'activity_requirement',''),
    v_rule.activity_requirement);
  IF v_days IS NULL OR v_days <= 0 THEN
    RAISE EXCEPTION 'Positive inactivity limit required' USING ERRCODE='KS400';
  END IF;
  RETURN jsonb_build_object(
    'active_lines',(SELECT count(*) FROM public.sim_lines
      WHERE carrier_id=p_carrier_id AND status='active'),
    'current_requirement',v_rule.activity_requirement,
    'proposed_requirement',v_requirement,
    'current_limit_days',v_rule.inactivity_limit_days,
    'proposed_limit_days',v_days,
    'eligibility_must_recalculate',v_requirement IS DISTINCT FROM v_rule.activity_requirement,
    'sample',(
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'sim_line_id',cs.sim_line_id,
        'current_state',cs.state,
        'current_cutoff',cs.deactivation_cutoff_at,
        'projected_cutoff',CASE
          WHEN v_requirement=v_rule.activity_requirement
            AND cs.deactivation_cutoff_at IS NOT NULL
          THEN cs.deactivation_cutoff_at +
            make_interval(days => v_days-v_rule.inactivity_limit_days)
          ELSE NULL END
      ) ORDER BY cs.hours_remaining NULLS LAST),'[]'::jsonb)
      FROM (SELECT * FROM public.sim_line_alert_clock_states
        WHERE carrier_id=p_carrier_id ORDER BY hours_remaining NULLS LAST LIMIT 10) cs
    )
  );
END;
$$;
REVOKE ALL ON FUNCTION public.admin_preview_carrier_alert_rule(uuid,jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_preview_carrier_alert_rule(uuid,jsonb)
  TO authenticated, service_role;

-- Rule edits invalidate clock state immediately. Pending alerts from a prior
-- activity/rule cycle are canceled; a leased send is checked again by the
-- outbox processor before provider dispatch.
CREATE OR REPLACE FUNCTION public.trg_fn_refresh_alert_clocks_on_rule()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE v_line record;
BEGIN
  FOR v_line IN SELECT id FROM public.sim_lines
    WHERE carrier_id=NEW.carrier_id AND status='active'
  LOOP
    PERFORM public.calculate_sim_line_alert_clock(v_line.id);
  END LOOP;
  UPDATE public.notification_dispatch_jobs j
  SET state='canceled', last_error='Carrier rule changed before dispatch',
      updated_at=now()
  FROM public.notifications n
  JOIN public.sim_line_alert_clock_states cs ON cs.sim_line_id=n.sim_line_id
  WHERE j.notification_id=n.id AND j.state='pending'
    AND n.event_type='line_deactivation_imminent'
    AND cs.carrier_id=NEW.carrier_id
    AND n.source_event_key IS DISTINCT FROM
      ('deactivation_48h:' || cs.sim_line_id || ':' || cs.alert_cycle_token);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_refresh_alert_clocks_on_rule ON public.carrier_rules;
CREATE TRIGGER trg_refresh_alert_clocks_on_rule
AFTER UPDATE OF inactivity_limit_days,activity_requirement,
  validity_qualifying_topup_amount,rule_source_url,last_verified_at
ON public.carrier_rules FOR EACH ROW
WHEN (OLD.* IS DISTINCT FROM NEW.*)
EXECUTE FUNCTION public.trg_fn_refresh_alert_clocks_on_rule();
