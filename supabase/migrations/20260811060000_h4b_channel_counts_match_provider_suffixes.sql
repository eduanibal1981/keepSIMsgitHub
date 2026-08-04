-- H4b — admin_list_channels().
--
-- The first cut joined notification_deliveries on `nd.channel = c.channel_key`,
-- but dispatch-alert does not log the channel, it logs the *route*: the real
-- values are push_onesignal and push_fcm, not push. So every push row in the
-- admin channel list would have read 0 sent / 0 failed while 31 real push
-- deliveries sat in the table. A dashboard that reports zero when the answer is
-- 31 is worse than one that reports nothing.
--
-- Found by running admin_notification_health() rather than by reading the join.
CREATE OR REPLACE FUNCTION public.admin_list_channels()
RETURNS TABLE (
  channel_key         text,
  label               text,
  is_globally_enabled boolean,
  provider            text,
  credential_secret   text,
  credential_status   text,
  min_tier            text,
  user_configurable   boolean,
  monthly_quota       integer,
  notes               text,
  sort_order          integer,
  users_enabled       bigint,
  sent_30d            bigint,
  failed_30d          bigint,
  skipped_30d         bigint,
  last_delivery_at    timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT c.channel_key, c.label, c.is_globally_enabled, c.provider, c.credential_secret,
         c.credential_status, c.min_tier, c.user_configurable, c.monthly_quota, c.notes, c.sort_order,
         (SELECT count(*) FROM public.notification_channels nc
           WHERE nc.channel_type = c.channel_key AND nc.is_enabled),
         COALESCE(d.sent, 0), COALESCE(d.failed, 0), COALESCE(d.skipped, 0), d.last_at
  FROM public.notification_channel_catalog c
  LEFT JOIN LATERAL (
    SELECT count(*) FILTER (WHERE nd.status IN ('sent','success','delivered')) AS sent,
           count(*) FILTER (WHERE nd.status = 'failed')                        AS failed,
           count(*) FILTER (WHERE nd.status = 'skipped')                       AS skipped,
           max(nd.created_at)                                                  AS last_at
    FROM public.notification_deliveries nd
    WHERE nd.created_at > now() - interval '30 days'
      -- channel_key, or channel_key with a provider suffix (push_onesignal,
      -- push_fcm). The underscore is escaped: unescaped it is a LIKE wildcard.
      AND (nd.channel = c.channel_key OR nd.channel LIKE c.channel_key || E'\\_%')
  ) d ON true
  ORDER BY c.sort_order;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_channels() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_channels() TO authenticated, service_role;
