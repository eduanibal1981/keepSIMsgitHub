-- Restore the two supplier-inspection reads used by the current Admin app.
-- This is only the read boundary from the pending retail ownership contract;
-- do not deploy that larger financial/catalogue migration to fix these views.
-- A later full contract cutover must reconcile its plain CREATE FUNCTION/VIEW
-- statements with these compatibility objects, as with the customer views.
BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE OR REPLACE FUNCTION public.authorize_admin_catalogue_read()
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.authorize_admin_catalogue_read() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.authorize_admin_catalogue_read() TO authenticated;

CREATE OR REPLACE VIEW public.admin_internal_provider_offers
WITH (security_barrier=true,security_invoker=false) AS
  SELECT t.* FROM public.provider_offers t
  WHERE (SELECT public.authorize_admin_catalogue_read());
REVOKE ALL ON public.admin_internal_provider_offers FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.admin_internal_provider_offers TO authenticated;

CREATE OR REPLACE VIEW public.admin_internal_provider_offers_cache
WITH (security_barrier=true,security_invoker=false) AS
  SELECT t.* FROM public.provider_offers_cache t
  WHERE (SELECT public.authorize_admin_catalogue_read());
REVOKE ALL ON public.admin_internal_provider_offers_cache FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.admin_internal_provider_offers_cache TO authenticated;

-- No base-table grants, rows, prices, credentials, runtime or worker changes.
NOTIFY pgrst, 'reload schema';
COMMIT;
