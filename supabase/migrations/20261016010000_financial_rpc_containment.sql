-- Containment only. Existing customer API grants are not globally changed.
BEGIN;

REVOKE ALL ON FUNCTION public.finalize_sim_setup_order(uuid,text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.reap_stuck_executions(integer,integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reap_stuck_executions(integer,integer) TO postgres, service_role;

REVOKE ALL ON FUNCTION public.resolve_app_fee(text,text,numeric),
  public.resolve_line_entitlement(uuid), public.resolve_account_commerce_benefit(uuid),
  public.has_paid_premium_entitlement(uuid), public.resolve_esim_offer_price(numeric,uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_app_fee(text,text,numeric),
  public.resolve_line_entitlement(uuid), public.resolve_account_commerce_benefit(uuid),
  public.has_paid_premium_entitlement(uuid), public.resolve_esim_offer_price(numeric,uuid)
  TO service_role;

-- Both bodies already qualify application tables. pg_catalog remains implicit.
ALTER FUNCTION public.trg_fn_notify_topup_result() SET search_path = '';
ALTER FUNCTION public.trg_scheduled_topup_health_sync() SET search_path = '';

-- Owner defaults, rather than session defaults: schema defaults ADD to global
-- defaults, so undo both. Do not silently skip an owner we cannot administer.
DO $$
DECLARE v_owner text;
BEGIN
  FOR v_owner IN
    SELECT DISTINCT r.rolname
    FROM pg_roles r
    WHERE r.oid IN (
      SELECT p.proowner FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND NOT EXISTS (
        SELECT 1 FROM pg_depend d WHERE d.classid='pg_proc'::regclass
          AND d.objid=p.oid AND d.deptype='e')
      UNION
      SELECT d.defaclrole FROM pg_default_acl d
      WHERE d.defaclobjtype='f' AND d.defaclnamespace IN (0,'public'::regnamespace)
    )
  LOOP
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated',v_owner);
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated',v_owner);
  END LOOP;
END;
$$;

COMMIT;
