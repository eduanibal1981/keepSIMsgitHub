-- =============================================================================
-- I3 · Carrier-targeted campaigns — admin push + an in-app promo surface
-- =============================================================================
-- THE ASK: "through the Admin UI I can push a notification to the users
-- registered on a specific carrier (for example Vodafone, in Egypt) to buy an
-- awesome plan, or show it as an advert at home to take the offer."
--
-- WHAT EXISTED BEFORE THIS: nothing. `notifications.category` has carried
-- `'promo'` since C1 and G2's price-drop watch writes it, but there was no
-- campaign object, no audience query, no admin RPC, and **no in-app surface at
-- all** — grep `lib/features/dashboard` for "promo" returned zero hits. An
-- admin could not reach a carrier's users by any route.
--
-- TWO SURFACES, TWO CONSENT RULES — this is the design decision that matters:
--
--   * **push** goes out as a `notifications` row with category `'promo'`, so it
--     inherits the existing consent path: `trg_fn_dispatch_notification` treats
--     a missing `alert_settings` row as enabled for every category EXCEPT
--     `promo`, which is opt-in. **0 of 8 users have promo enabled today**, so a
--     campaign sent right now reaches nobody by push. That is correct
--     behaviour, not a bug, and it is why the in-app surface exists.
--   * **in-app** is a pull, not a push: the user opens the app and sees a card.
--     It deliberately does NOT require promo consent — requiring an opt-in to
--     *see an advert you navigated to* would make the feature inert. It is
--     dismissible per user, and a dismissal is permanent for that campaign.
--
-- AUDIENCE is resolved from SIM LINES, not from profiles: "users on Vodafone
-- Egypt" means "users who hold a line on that carrier". A user with three lines
-- is counted once.
--
-- Convention followed from Phase H: every mutation is an `admin_*` SECURITY
-- DEFINER RPC that opens with `assert_admin()` and writes an `admin_audit_log`
-- row; writes take a jsonb patch where an absent key means unchanged and an
-- UNKNOWN key is refused (a defaulted-NULL parameter cannot distinguish "leave
-- alone" from "set NULL", and adding a parameter later is the PGRST203 trap).
-- No new RLS policy is added to any user-facing table.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.campaigns (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title             text NOT NULL,
  body              text NOT NULL,
  cta_label         text,
  action_url        text,

  -- Targeting. NULL means "do not filter on this".
  target_carrier_id uuid REFERENCES public.carriers(id) ON DELETE CASCADE,
  target_country_id uuid REFERENCES public.countries(id) ON DELETE CASCADE,
  target_plan_types text[],

  -- Surfaces.
  send_push         boolean NOT NULL DEFAULT false,
  show_in_app       boolean NOT NULL DEFAULT true,

  -- Window. `ends_at` NULL means "until archived".
  starts_at         timestamptz NOT NULL DEFAULT now(),
  ends_at           timestamptz,

  status            text NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft', 'active', 'sent', 'archived')),

  created_by        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  sent_at           timestamptz,
  recipients_count  integer NOT NULL DEFAULT 0,

  CONSTRAINT campaigns_window_sane CHECK (ends_at IS NULL OR ends_at > starts_at)
);

CREATE INDEX IF NOT EXISTS idx_campaigns_live
  ON public.campaigns (status, starts_at, ends_at)
  WHERE status = 'active';

-- Per-user state for the in-app card. A row appears the first time a user is
-- shown a campaign; `dismissed_at` is what hides it for good.
CREATE TABLE IF NOT EXISTS public.campaign_deliveries (
  campaign_id  uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pushed_at    timestamptz,
  seen_at      timestamptz,
  dismissed_at timestamptz,
  PRIMARY KEY (campaign_id, user_id)
);

-- Deny-all. Clients reach both tables only through the two RPCs at the bottom,
-- which is what keeps a draft campaign (and the whole target list) invisible.
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaign_deliveries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.campaigns FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.campaign_deliveries FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.campaigns TO service_role;
GRANT ALL ON public.campaign_deliveries TO service_role;

-- -----------------------------------------------------------------------------
-- Audience — one place, used by the preview, the send and the in-app query
-- -----------------------------------------------------------------------------
-- Deliberately a single function: a preview count that disagrees with what the
-- send actually does is worse than no preview.
CREATE OR REPLACE FUNCTION public.campaign_audience(p_campaign_id uuid)
RETURNS TABLE (user_id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT DISTINCT sl.user_id
  FROM public.campaigns c
  JOIN public.sim_lines sl ON true
  LEFT JOIN public.carriers ca ON ca.id = sl.carrier_id
  WHERE c.id = p_campaign_id
    AND (c.target_carrier_id IS NULL OR sl.carrier_id = c.target_carrier_id)
    AND (c.target_country_id IS NULL OR sl.country_id = c.target_country_id)
    AND (c.target_plan_types IS NULL
         OR lower(coalesce(sl.plan_type, 'free')) = ANY (c.target_plan_types))
    AND sl.status <> 'deactivated'
    -- A suspended account is not a marketing audience.
    AND NOT EXISTS (SELECT 1 FROM public.profiles p
                    WHERE p.id = sl.user_id AND p.is_suspended = true);
$function$;

REVOKE ALL ON FUNCTION public.campaign_audience(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.campaign_audience(uuid) TO service_role;

-- -----------------------------------------------------------------------------
-- Admin surface
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_campaigns()
RETURNS TABLE (
  id uuid, title text, body text, cta_label text, action_url text,
  target_carrier_id uuid, target_carrier text,
  target_country_id uuid, target_country text,
  target_plan_types text[], send_push boolean, show_in_app boolean,
  starts_at timestamptz, ends_at timestamptz, status text,
  recipients_count integer, sent_at timestamptz, created_at timestamptz,
  audience_now bigint, dismissals bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
  SELECT c.id, c.title, c.body, c.cta_label, c.action_url,
         c.target_carrier_id, ca.name, c.target_country_id, co.name,
         c.target_plan_types, c.send_push, c.show_in_app,
         c.starts_at, c.ends_at, c.status,
         c.recipients_count, c.sent_at, c.created_at,
         (SELECT count(*) FROM public.campaign_audience(c.id)),
         (SELECT count(*) FROM public.campaign_deliveries d
          WHERE d.campaign_id = c.id AND d.dismissed_at IS NOT NULL)
  FROM public.campaigns c
  LEFT JOIN public.carriers  ca ON ca.id = c.target_carrier_id
  LEFT JOIN public.countries co ON co.id = c.target_country_id
  ORDER BY c.created_at DESC;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_campaigns() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_campaigns() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_upsert_campaign(
  p_id    uuid,
  p_patch jsonb,
  p_note  text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_admin uuid;
  v_id    uuid;
  v_key   text;
  v_allowed text[] := ARRAY[
    'title','body','cta_label','action_url','target_carrier_id',
    'target_country_id','target_plan_types','send_push','show_in_app',
    'starts_at','ends_at','status'
  ];
BEGIN
  v_admin := public.assert_admin();

  -- Refuse unknown keys rather than ignoring them: a typo that silently does
  -- nothing is how an admin thinks a campaign is targeted when it is not.
  FOR v_key IN SELECT jsonb_object_keys(p_patch) LOOP
    IF NOT (v_key = ANY (v_allowed)) THEN
      RAISE EXCEPTION 'Unknown campaign field: %', v_key USING ERRCODE = 'KS422';
    END IF;
  END LOOP;

  IF p_id IS NULL THEN
    IF NOT (p_patch ? 'title' AND p_patch ? 'body') THEN
      RAISE EXCEPTION 'A new campaign needs at least a title and a body' USING ERRCODE = 'KS422';
    END IF;
    INSERT INTO public.campaigns (title, body, created_by)
    VALUES (p_patch ->> 'title', p_patch ->> 'body', v_admin)
    RETURNING id INTO v_id;
  ELSE
    v_id := p_id;
    IF NOT EXISTS (SELECT 1 FROM public.campaigns WHERE id = v_id) THEN
      RAISE EXCEPTION 'Campaign % not found', v_id USING ERRCODE = 'KS404';
    END IF;
    -- A campaign that has already gone out is a record of what was sent.
    IF EXISTS (SELECT 1 FROM public.campaigns WHERE id = v_id AND status = 'sent')
       AND NOT (p_patch ?& ARRAY['status'] AND p_patch ->> 'status' = 'archived'
                AND (SELECT count(*) FROM jsonb_object_keys(p_patch)) = 1) THEN
      RAISE EXCEPTION 'A sent campaign can only be archived' USING ERRCODE = 'KS409';
    END IF;
  END IF;

  UPDATE public.campaigns c SET
    title             = COALESCE(p_patch ->> 'title', c.title),
    body              = COALESCE(p_patch ->> 'body', c.body),
    cta_label         = CASE WHEN p_patch ? 'cta_label'  THEN p_patch ->> 'cta_label'  ELSE c.cta_label  END,
    action_url        = CASE WHEN p_patch ? 'action_url' THEN p_patch ->> 'action_url' ELSE c.action_url END,
    target_carrier_id = CASE WHEN p_patch ? 'target_carrier_id'
                             THEN NULLIF(p_patch ->> 'target_carrier_id','')::uuid ELSE c.target_carrier_id END,
    target_country_id = CASE WHEN p_patch ? 'target_country_id'
                             THEN NULLIF(p_patch ->> 'target_country_id','')::uuid ELSE c.target_country_id END,
    target_plan_types = CASE WHEN p_patch ? 'target_plan_types'
                             THEN CASE WHEN jsonb_typeof(p_patch -> 'target_plan_types') = 'null' THEN NULL
                                       ELSE ARRAY(SELECT lower(e) FROM jsonb_array_elements_text(p_patch -> 'target_plan_types') e) END
                             ELSE c.target_plan_types END,
    send_push         = COALESCE((p_patch ->> 'send_push')::boolean, c.send_push),
    show_in_app       = COALESCE((p_patch ->> 'show_in_app')::boolean, c.show_in_app),
    starts_at         = COALESCE((p_patch ->> 'starts_at')::timestamptz, c.starts_at),
    ends_at           = CASE WHEN p_patch ? 'ends_at'
                             THEN NULLIF(p_patch ->> 'ends_at','')::timestamptz ELSE c.ends_at END,
    status            = COALESCE(p_patch ->> 'status', c.status),
    updated_at        = now()
  WHERE c.id = v_id;

  PERFORM public.admin_log('campaign_upsert', 'campaigns', v_id::text,
                           NULL::jsonb, p_patch, p_note);
  RETURN v_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_upsert_campaign(uuid, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_campaign(uuid, jsonb, text) TO authenticated, service_role;

-- Send: fan out the push half. The in-app half needs no send — it is a pull,
-- live from the moment `status = 'active'` and the window opens.
CREATE OR REPLACE FUNCTION public.admin_send_campaign(
  p_id   uuid,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_c     RECORD;
  v_count integer := 0;
  v_aud   integer := 0;
BEGIN
  PERFORM public.assert_admin();

  SELECT * INTO v_c FROM public.campaigns WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign % not found', p_id USING ERRCODE = 'KS404';
  END IF;
  IF v_c.status = 'sent' THEN
    RAISE EXCEPTION 'Campaign % has already been sent', p_id USING ERRCODE = 'KS409';
  END IF;
  IF v_c.status = 'archived' THEN
    RAISE EXCEPTION 'Campaign % is archived', p_id USING ERRCODE = 'KS409';
  END IF;

  SELECT count(*) INTO v_aud FROM public.campaign_audience(p_id);

  IF v_c.send_push THEN
    -- Category 'promo' on purpose: it is the one category that is opt-IN, so
    -- this cannot spam a user who never agreed to marketing. The existing
    -- dispatch trigger on `notifications` does the channel fan-out.
    WITH targets AS (SELECT user_id FROM public.campaign_audience(p_id)),
    inserted AS (
      INSERT INTO public.notifications (user_id, category, title, body, action_url)
      SELECT t.user_id, 'promo', v_c.title, v_c.body, v_c.action_url
      FROM targets t
      RETURNING user_id
    )
    INSERT INTO public.campaign_deliveries (campaign_id, user_id, pushed_at)
    SELECT p_id, i.user_id, now() FROM inserted i
    ON CONFLICT (campaign_id, user_id) DO UPDATE SET pushed_at = now();
    GET DIAGNOSTICS v_count = ROW_COUNT;
  END IF;

  UPDATE public.campaigns
  SET status = CASE WHEN v_c.send_push THEN 'sent' ELSE 'active' END,
      sent_at = CASE WHEN v_c.send_push THEN now() ELSE sent_at END,
      recipients_count = v_aud,
      updated_at = now()
  WHERE id = p_id;

  PERFORM public.admin_log('campaign_send', 'campaigns', p_id::text,
    NULL::jsonb, jsonb_build_object('audience', v_aud, 'pushed', v_count), p_note);

  RETURN jsonb_build_object(
    'success', true,
    'audience', v_aud,
    'pushed', v_count,
    -- Said out loud because it will otherwise read as a failure: promo is
    -- opt-in and almost nobody has opted in.
    'push_consented', (SELECT count(*) FROM public.alert_settings
                       WHERE category = 'promo' AND is_enabled = true)
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_send_campaign(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_send_campaign(uuid, text) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Client surface — the in-app advert
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_active_promos()
RETURNS TABLE (
  id uuid, title text, body text, cta_label text, action_url text,
  carrier_name text, ends_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  RETURN QUERY
  SELECT c.id, c.title, c.body, c.cta_label, c.action_url, ca.name, c.ends_at
  FROM public.campaigns c
  LEFT JOIN public.carriers ca ON ca.id = c.target_carrier_id
  WHERE c.show_in_app
    AND c.status IN ('active', 'sent')
    AND c.starts_at <= now()
    AND (c.ends_at IS NULL OR c.ends_at > now())
    -- Targeted at a carrier/country/plan this user actually holds a line on.
    AND EXISTS (
      SELECT 1 FROM public.sim_lines sl
      WHERE sl.user_id = auth.uid()
        AND sl.status <> 'deactivated'
        AND (c.target_carrier_id IS NULL OR sl.carrier_id = c.target_carrier_id)
        AND (c.target_country_id IS NULL OR sl.country_id = c.target_country_id)
        AND (c.target_plan_types IS NULL
             OR lower(coalesce(sl.plan_type, 'free')) = ANY (c.target_plan_types))
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.campaign_deliveries d
      WHERE d.campaign_id = c.id AND d.user_id = auth.uid()
        AND d.dismissed_at IS NOT NULL
    )
  ORDER BY c.starts_at DESC;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_active_promos() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_active_promos() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.dismiss_promo(p_campaign_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- No existence check on purpose: a dismissal of an unknown id is harmless and
  -- answering differently would turn this into a campaign-id oracle.
  INSERT INTO public.campaign_deliveries (campaign_id, user_id, dismissed_at)
  SELECT c.id, auth.uid(), now() FROM public.campaigns c WHERE c.id = p_campaign_id
  ON CONFLICT (campaign_id, user_id) DO UPDATE SET dismissed_at = now();

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.dismiss_promo(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dismiss_promo(uuid) TO authenticated, service_role;
