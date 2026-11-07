-- Display-only batch. Keep the existing checkout selector and settlement rules.
BEGIN;

CREATE FUNCTION carrier_availability_private.valid_premium_fee(p_price numeric)
RETURNS boolean LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE fee numeric;
BEGIN
  fee := public.resolve_app_fee('refills','premium',p_price);
  RETURN coalesce(fee >= 0 AND fee::text NOT IN ('NaN','Infinity','-Infinity'),false);
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END $$;
REVOKE ALL ON FUNCTION carrier_availability_private.valid_premium_fee(numeric)
  FROM PUBLIC,anon,authenticated,service_role;

-- Later environment policy releases tighten the same predicate for display
-- and checkout without reintroducing per-carrier catalogue evaluation.
CREATE FUNCTION carrier_availability_private.airtime_environment_allowed(p_provider text,p_environment text,p_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$ SELECT true $$;
REVOKE ALL ON FUNCTION carrier_availability_private.airtime_environment_allowed(text,text,uuid)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.admin_list_carrier_offer_counts()
RETURNS TABLE(carrier_id uuid,available_offer_count bigint,available_provider_count bigint,
  premium_available boolean,premium_unavailable_reason text,evaluated_at timestamptz,valid_until timestamptz,
  provider_breakdown jsonb,catalogue_offer_count bigint,test_offer_count bigint,catalogue_provider_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
  WITH candidates AS MATERIALIZED (
    SELECT * FROM carrier_availability_private.catalogue_candidates
  ), states AS MATERIALIZED (
    SELECT * FROM carrier_availability_private.offer_state
  ), offers AS MATERIALIZED (
    SELECT a.carrier_id,a.provider_code,
      count(*) offers,count(*) FILTER (WHERE a.is_test) tests,
      count(*) FILTER (WHERE NOT a.is_test) production,
      count(*) FILTER (WHERE a.environment='sandbox') sandbox,
      count(*) FILTER (WHERE a.environment='preproduction') preproduction,
      min(a.expires_at) expires
    FROM candidates a
    GROUP BY a.carrier_id,a.provider_code
  ), totals AS (
    SELECT o.carrier_id,sum(o.offers)::bigint offers,sum(o.tests)::bigint tests,
      sum(o.production)::bigint production,count(*) providers,
      count(*) FILTER (WHERE o.production>0) production_providers,min(o.expires) expires
    FROM offers o GROUP BY o.carrier_id
  ), diagnostics AS MATERIALIZED (
    SELECT s.carrier_id,s.provider_code,
      bool_or(s.is_routable AND s.sandbox) has_sandbox,
      bool_or(s.is_routable AND NOT s.fresh) has_stale,
      count(*) FILTER (WHERE NOT s.fresh) stale,
      count(*) FILTER (WHERE NOT s.published) pending
    FROM states s GROUP BY s.carrier_id,s.provider_code
  ), previews AS MATERIALIZED (
    SELECT m.carrier_id,
      sum(jsonb_array_length(p.offers))::bigint products,
      bool_or(r.is_routable AND jsonb_array_length(p.offers)>0) has_preview
    FROM dtone_private.preview_catalogues p
    JOIN dtone_private.configs cfg ON cfg.environment='preproduction' AND cfg.version=p.credential_version
    JOIN public.carrier_provider_map m ON m.provider='dtone'
      AND m.provider_country_code=p.country_code AND m.provider_carrier_code=p.carrier_code
    LEFT JOIN public.carrier_supplier_routing r ON r.carrier_id=m.carrier_id AND r.provider_code=m.provider
    WHERE p.refreshed_at>now()-interval '24 hours' GROUP BY m.carrier_id
  ), rails AS (
    SELECT m.carrier_id,bool_or(r.is_routable) enabled,
      bool_or(d.has_stale) has_stale,bool_or(d.has_sandbox) has_sandbox,
      jsonb_object_agg(m.provider,jsonb_build_object(
        'available_offer_count',coalesce(o.production,0),
        'preview_offer_count',CASE WHEN m.provider='dtone' THEN coalesce(p.products,0) ELSE 0 END,
        'stale_offer_count',coalesce(d.stale,0),
        'pending_offer_count',coalesce(d.pending,0),
        'catalogue_offer_count',coalesce(o.offers,0),
        'test_offer_count',coalesce(o.tests,0),
        'production_offer_count',coalesce(o.production,0),
        'sandbox_offer_count',coalesce(o.sandbox,0),
        'preproduction_offer_count',coalesce(o.preproduction,0))) breakdown
    FROM public.carrier_provider_map m
    LEFT JOIN public.carrier_supplier_routing r ON r.carrier_id=m.carrier_id AND r.provider_code=m.provider
    LEFT JOIN offers o ON o.carrier_id=m.carrier_id AND o.provider_code=m.provider
    LEFT JOIN diagnostics d ON d.carrier_id=m.carrier_id AND d.provider_code=m.provider
    LEFT JOIN previews p ON p.carrier_id=m.carrier_id
    GROUP BY m.carrier_id
  ), rules AS MATERIALIZED (
    SELECT DISTINCT ON (r.carrier_id) r.carrier_id,r.minimum_topup_amount,r.validity_qualifying_topup_amount,
      r.activity_requirement,r.inactivity_limit_days,r.refill_interval_days_override,
      nullif(greatest(coalesce(r.validity_qualifying_topup_amount,r.minimum_topup_amount,0),
        coalesce(public.carrier_qualifying_topup_amount(r.carrier_id),0)),0) minimum
    FROM public.carrier_rules r ORDER BY r.carrier_id,r.updated_at DESC NULLS LAST,r.id
  ), prices AS MATERIALIZED (
    SELECT s.carrier_id,s.provider_code,s.offer_id,false is_preview,r.is_primary,r.priority,
      o.source_price_type,o.effective_price_usd,o.source_price_min_usd,o.source_price_max_usd,
      coalesce(o.delivery_type,'direct') delivery_type
    FROM states s
    JOIN public.provider_offers o ON o.id=s.catalogue_id AND o.offer_code=s.offer_id
    JOIN public.carrier_supplier_routing r ON r.carrier_id=s.carrier_id AND r.provider_code=s.provider_code
    UNION ALL
    SELECT r.carrier_id,r.provider_code,p.offer_id,true,r.is_primary,r.priority,
      p.price_type,p.price_fixed_usd,p.price_min_usd,p.price_max_usd,coalesce(p.delivery_type,'direct')
    FROM dtone_private.preview_catalogues preview
    JOIN public.carrier_supplier_routing r ON r.provider_code='dtone'
      AND r.provider_country_code=preview.country_code AND r.provider_carrier_code=preview.carrier_code
    CROSS JOIN LATERAL jsonb_populate_recordset(NULL::public.provider_offers_cache,preview.offers) p
    WHERE EXISTS (SELECT 1 FROM dtone_private.runtime WHERE id)
  ), qualifying AS (
    SELECT DISTINCT ON (p.carrier_id) p.carrier_id,
      CASE WHEN p.source_price_type='RANGE' THEN greatest(p.source_price_min_usd,
        least(p.source_price_max_usd,coalesce(r.minimum,p.source_price_min_usd)))
        ELSE p.effective_price_usd END price
    FROM prices p
    JOIN candidates a ON a.carrier_id=p.carrier_id AND a.provider_code=p.provider_code
      AND a.offer_id=p.offer_id AND p.is_preview=(a.environment='preproduction')
    JOIN rules r ON r.carrier_id=p.carrier_id
    WHERE carrier_availability_private.airtime_environment_allowed(p.provider_code,a.environment,auth.uid())
      AND (r.minimum IS NULL
      OR p.source_price_type='RANGE' AND p.source_price_max_usd>=r.minimum
      OR p.source_price_type='FIXED' AND p.effective_price_usd>=r.minimum)
    -- Match premium_offer so the display checks the fee for the same product.
    ORDER BY p.carrier_id,a.is_test,NOT p.is_primary,p.delivery_type<>'direct',price,p.priority,p.offer_id
  ), evaluated AS (
    SELECT c.id,t.production,t.production_providers,t.expires,r.breakdown,t.offers,t.tests,t.providers,
      CASE WHEN c.is_supported IS DISTINCT FROM true OR co.is_supported IS DISTINCT FROM true
          THEN 'carrier_not_supported'
        WHEN r.enabled IS DISTINCT FROM true THEN 'no_enabled_provider'
        WHEN t.offers IS NULL THEN CASE
          WHEN r.has_sandbox OR p.has_preview THEN 'test_catalogue_only'
          WHEN r.has_stale THEN 'stale_catalogue'
          ELSE 'no_available_offers' END
        WHEN NOT carrier_availability_private.positive(rule.minimum_topup_amount) THEN 'carrier_rule_missing'
        WHEN rule.activity_requirement='usage_required' THEN 'usage_required'
        WHEN rule.activity_requirement='min_denomination'
          AND rule.minimum_topup_amount<rule.validity_qualifying_topup_amount THEN 'no_qualifying_offer'
        WHEN coalesce(public.refill_interval_days(rule.inactivity_limit_days,rule.refill_interval_days_override),0)<1
          THEN 'carrier_rule_missing'
        WHEN q.carrier_id IS NULL THEN 'no_qualifying_offer'
        WHEN NOT carrier_availability_private.valid_premium_fee(q.price) THEN 'pricing_unavailable'
        WHEN coalesce(c.fulfillment_gateway,'API') NOT IN ('API','MANUAL','TASKER_SCRIPT')
          THEN 'fulfillment_unavailable' END reason
    FROM public.carriers c
    LEFT JOIN public.countries co ON co.id=c.country_id
    LEFT JOIN totals t ON t.carrier_id=c.id
    LEFT JOIN rails r ON r.carrier_id=c.id
    LEFT JOIN previews p ON p.carrier_id=c.id
    LEFT JOIN rules rule ON rule.carrier_id=c.id
    LEFT JOIN qualifying q ON q.carrier_id=c.id
  )
  SELECT e.id,coalesce(e.production,0),coalesce(e.production_providers,0),e.reason IS NULL,e.reason,
    now(),least(now()+interval '60 seconds',e.expires),coalesce(e.breakdown,'{}'::jsonb),
    coalesce(e.offers,0),coalesce(e.tests,0),coalesce(e.providers,0)
  FROM evaluated e;
END $$;
COMMIT;
