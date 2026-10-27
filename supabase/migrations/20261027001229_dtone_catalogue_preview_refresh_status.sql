BEGIN;
CREATE FUNCTION public.admin_dtone_preview_status() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
  PERFORM public.assert_admin();
  SELECT jsonb_build_object('refreshed_at',max(preview.refreshed_at),
    'offer_count',coalesce(sum(jsonb_array_length(preview.offers)),0)) INTO result
  FROM dtone_private.preview_catalogues preview JOIN dtone_private.configs config
    ON config.environment='preproduction' AND config.version=preview.credential_version;
  RETURN result;
END$$;
REVOKE ALL ON FUNCTION public.admin_dtone_preview_status() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.admin_dtone_preview_status() TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
