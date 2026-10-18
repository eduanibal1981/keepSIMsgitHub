-- ============================================================================
-- H7a — the support desk.
--
-- C7 shipped the user-facing half: support_tickets and ticket_messages exist,
-- users can open a ticket and post to it. Nobody could ever answer. There is no
-- policy giving support staff read access, no path to insert a sender='admin'
-- message, and the review's own note says replying today means opening the
-- Supabase dashboard.
--
-- Replies go through an RPC rather than new RLS policies for one specific
-- reason: answering a ticket must also NOTIFY the user, and a policy cannot do
-- that. Answering into a table nobody watches is the same as not answering.
--
-- (admin_reply_ticket's final body lives in 20260811120000_h7d — the first cut
-- sent a SECOND notification on top of C7's existing trigger.)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_list_tickets(
  p_status text    DEFAULT NULL,
  p_limit  integer DEFAULT 100
)
RETURNS TABLE (
  id             uuid,
  user_id        uuid,
  user_email     text,
  user_name      text,
  subject        text,
  category       text,
  status         text,
  priority       text,
  sim_line_id    uuid,
  created_at     timestamptz,
  updated_at     timestamptz,
  message_count  bigint,
  last_message_at timestamptz,
  last_sender    text,
  awaiting_reply boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT t.id, t.user_id, p.email, p.full_name, t.subject, t.category, t.status,
         t.priority, t.sim_line_id, t.created_at, t.updated_at,
         COALESCE(m.n, 0), m.last_at, m.last_sender,
         -- The queue's actual ordering signal: a ticket whose newest message is
         -- from the user, or which has no messages at all, is owed an answer.
         COALESCE(m.last_sender, 'user') = 'user' AND t.status NOT IN ('resolved','closed')
  FROM public.support_tickets t
  LEFT JOIN public.profiles p ON p.id = t.user_id
  LEFT JOIN LATERAL (
    SELECT count(*) n, max(tm.created_at) last_at,
           (array_agg(tm.sender ORDER BY tm.created_at DESC))[1] last_sender
    FROM public.ticket_messages tm WHERE tm.ticket_id = t.id
  ) m ON true
  WHERE p_status IS NULL OR t.status = p_status
  ORDER BY
    (COALESCE(m.last_sender,'user') = 'user' AND t.status NOT IN ('resolved','closed')) DESC,
    CASE t.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    COALESCE(m.last_at, t.created_at) ASC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_tickets(text,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_tickets(text,integer) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_get_ticket(p_ticket_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE v jsonb;
BEGIN
  PERFORM public.assert_admin();

  SELECT jsonb_build_object(
    'ticket', to_jsonb(t) - 'user_id' || jsonb_build_object('user_id', t.user_id),
    'user', jsonb_build_object('id', p.id, 'email', p.email, 'full_name', p.full_name,
                               'tier', p.subscription_tier, 'suspended', p.is_suspended),
    'wallet_balance_usd', (SELECT w.balance FROM public.wallets w WHERE w.user_id = t.user_id),
    'messages', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id', tm.id, 'sender', tm.sender, 'message', tm.message,
               'attachments', tm.attachments, 'created_at', tm.created_at)
             ORDER BY tm.created_at)
      FROM public.ticket_messages tm WHERE tm.ticket_id = t.id), '[]'::jsonb)
  ) INTO v
  FROM public.support_tickets t
  LEFT JOIN public.profiles p ON p.id = t.user_id
  WHERE t.id = p_ticket_id;

  IF v IS NULL THEN
    RAISE EXCEPTION 'Ticket % not found', p_ticket_id USING ERRCODE = 'KS461';
  END IF;
  RETURN v;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_ticket(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_ticket(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_set_ticket_status(
  p_ticket_id uuid,
  p_status    text,
  p_priority  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE v_before RECORD;
BEGIN
  PERFORM public.assert_admin();

  IF p_status NOT IN ('open','pending','resolved','closed') THEN
    RAISE EXCEPTION 'Status must be open, pending, resolved or closed' USING ERRCODE = 'KS466';
  END IF;
  IF p_priority IS NOT NULL AND p_priority NOT IN ('low','medium','high','urgent') THEN
    RAISE EXCEPTION 'Priority must be low, medium, high or urgent' USING ERRCODE = 'KS466';
  END IF;

  SELECT * INTO v_before FROM public.support_tickets WHERE id = p_ticket_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ticket % not found', p_ticket_id USING ERRCODE = 'KS461';
  END IF;

  UPDATE public.support_tickets
  SET status = p_status, priority = COALESCE(p_priority, priority), updated_at = now()
  WHERE id = p_ticket_id;

  PERFORM public.admin_log('ticket.status', 'support_ticket', p_ticket_id::text,
    jsonb_build_object('status', v_before.status, 'priority', v_before.priority),
    jsonb_build_object('status', p_status, 'priority', COALESCE(p_priority, v_before.priority)),
    NULL);

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_ticket_status(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_ticket_status(uuid,text,text) TO authenticated, service_role;
