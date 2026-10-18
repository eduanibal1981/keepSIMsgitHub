-- Expose only operational metadata. Payloads and recipient identifiers stay private.
CREATE OR REPLACE FUNCTION public.admin_list_notification_dispatch_incidents(
  p_limit integer DEFAULT 50
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN COALESCE((
    SELECT jsonb_agg(to_jsonb(incident) ORDER BY incident.created_at DESC)
    FROM (
      SELECT j.id, j.notification_id, j.state, j.attempt_count,
        j.last_error, j.created_at, j.updated_at,
        n.event_type,
        j.state = 'failed' AND NOT EXISTS (
          SELECT 1 FROM public.notification_deliveries d
          WHERE d.notification_id=j.notification_id
            AND d.status IN ('accepted_by_provider','delivered','unknown',
                             'attempting','retrying')
        ) AS safe_to_retry
      FROM public.notification_dispatch_jobs j
      JOIN public.notifications n ON n.id=j.notification_id
      WHERE j.state IN ('failed','unknown')
      ORDER BY j.created_at DESC
      LIMIT LEAST(GREATEST(COALESCE(p_limit,50),1),100)
    ) incident
  ), '[]'::jsonb);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_list_notification_dispatch_incidents(integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_notification_dispatch_incidents(integer)
  TO authenticated, service_role;
