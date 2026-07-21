-- ============================================================================
-- SIM Shield — Phase C7: Native Support Tickets & Realtime Thread Messaging
-- ============================================================================

-- 1. Create support_tickets table
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sim_line_id UUID REFERENCES public.sim_lines(id) ON DELETE SET NULL,
  subject TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL DEFAULT 'general',
  status TEXT NOT NULL DEFAULT 'open',
  priority TEXT NOT NULL DEFAULT 'medium',
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- Ensure columns exist if table pre-existed
ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS sim_line_id UUID REFERENCES public.sim_lines(id) ON DELETE SET NULL;
ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.support_tickets ALTER COLUMN description DROP NOT NULL;
ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'medium';

-- Add/update CHECK constraints
ALTER TABLE public.support_tickets DROP CONSTRAINT IF EXISTS support_tickets_category_check;
ALTER TABLE public.support_tickets ADD CONSTRAINT support_tickets_category_check CHECK (category IN ('general', 'billing', 'technical', 'refill_issue', 'account'));

ALTER TABLE public.support_tickets DROP CONSTRAINT IF EXISTS support_tickets_status_check;
ALTER TABLE public.support_tickets ADD CONSTRAINT support_tickets_status_check CHECK (status IN ('open', 'pending', 'resolved', 'closed'));

ALTER TABLE public.support_tickets DROP CONSTRAINT IF EXISTS support_tickets_priority_check;
ALTER TABLE public.support_tickets ADD CONSTRAINT support_tickets_priority_check CHECK (priority IN ('low', 'medium', 'high', 'urgent'));

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_support_tickets_user_id ON public.support_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON public.support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_updated_at ON public.support_tickets(updated_at DESC);

-- Enable RLS on support_tickets
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own support tickets" ON public.support_tickets;
CREATE POLICY "Users can view own support tickets"
  ON public.support_tickets
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own support tickets" ON public.support_tickets;
CREATE POLICY "Users can create own support tickets"
  ON public.support_tickets
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own support tickets status" ON public.support_tickets;
CREATE POLICY "Users can update own support tickets status"
  ON public.support_tickets
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND status IN ('open', 'closed')
  );

-- 2. Create ticket_messages table
CREATE TABLE IF NOT EXISTS public.ticket_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sender TEXT NOT NULL CHECK (sender IN ('user', 'admin')),
  message TEXT NOT NULL,
  attachments JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- Index for thread sorting
CREATE INDEX IF NOT EXISTS idx_ticket_messages_ticket_id ON public.ticket_messages(ticket_id, created_at ASC);

-- Enable RLS on ticket_messages
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view messages for own tickets" ON public.ticket_messages;
CREATE POLICY "Users can view messages for own tickets"
  ON public.ticket_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.support_tickets st
      WHERE st.id = ticket_messages.ticket_id
        AND st.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can insert user messages for own tickets" ON public.ticket_messages;
CREATE POLICY "Users can insert user messages for own tickets"
  ON public.ticket_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    sender = 'user'
    AND user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.support_tickets st
      WHERE st.id = ticket_messages.ticket_id
        AND st.user_id = auth.uid()
    )
  );

-- Enable Supabase Realtime for ticket_messages
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'ticket_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ticket_messages;
  END IF;
END $$;

-- 3. Notification Category Expansion ('support')
-- Expand CHECK constraints from 12 categories to 13 categories
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_category_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_category_check CHECK (
  category IN (
    'top_up_success',
    'top_up_failed',
    'wallet_low',
    'wallet_depleted',
    'line_critical',
    'line_entering_grace',
    'geo_fence_triggered',
    'welcome_home_ready',
    'referral_reward',
    'system',
    'wallet_credit',
    'promo',
    'support'
  )
);

ALTER TABLE public.alert_settings DROP CONSTRAINT IF EXISTS alert_settings_category_check;
ALTER TABLE public.alert_settings ADD CONSTRAINT alert_settings_category_check CHECK (
  category IN (
    'top_up_success',
    'top_up_failed',
    'wallet_low',
    'wallet_depleted',
    'line_critical',
    'line_entering_grace',
    'geo_fence_triggered',
    'welcome_home_ready',
    'referral_reward',
    'system',
    'wallet_credit',
    'promo',
    'support'
  )
);

-- Update seed function to include 'support' (enabled by default)
CREATE OR REPLACE FUNCTION public.seed_default_alert_settings()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  INSERT INTO public.alert_settings (user_id, category, is_enabled, channels)
  SELECT NEW.id,
         c.category,
         c.category <> 'promo',
         ARRAY['push','email','telegram','whatsapp']::text[]
  FROM unnest(ARRAY[
    'top_up_success','top_up_failed','wallet_low','wallet_depleted','line_critical',
    'line_entering_grace','geo_fence_triggered','welcome_home_ready','referral_reward',
    'system','wallet_credit','promo','support'
  ]) AS c(category)
  ON CONFLICT (user_id, category) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Backfill 'support' category for existing users
INSERT INTO public.alert_settings (user_id, category, is_enabled, channels)
SELECT id, 'support', true, ARRAY['push','email','telegram','whatsapp']::text[]
FROM auth.users
ON CONFLICT (user_id, category) DO NOTHING;

-- 4. Trigger on ticket_messages for admin reply notifications & ticket status updates
CREATE OR REPLACE FUNCTION public.trg_fn_support_ticket_messages_process()
RETURNS TRIGGER AS $$
DECLARE
  v_ticket_owner UUID;
BEGIN
  -- Fetch ticket owner
  SELECT user_id INTO v_ticket_owner
  FROM public.support_tickets
  WHERE id = NEW.ticket_id;

  IF v_ticket_owner IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.sender = 'admin' THEN
    -- Update ticket status to pending (awaiting user response) and touch updated_at
    UPDATE public.support_tickets
    SET status = 'pending',
        updated_at = clock_timestamp()
    WHERE id = NEW.ticket_id;

    -- Insert notification row for the user (triggers trg_fn_dispatch_notification)
    INSERT INTO public.notifications (
      user_id,
      category,
      title,
      body,
      action_url
    ) VALUES (
      v_ticket_owner,
      'support',
      'New reply on support ticket',
      CASE 
        WHEN length(NEW.message) > 120 THEN substring(NEW.message from 1 for 117) || '...'
        ELSE NEW.message
      END,
      '/support/' || NEW.ticket_id::text
    );
  ELSIF NEW.sender = 'user' THEN
    -- Update ticket status to open (awaiting admin response) and touch updated_at
    UPDATE public.support_tickets
    SET status = 'open',
        updated_at = clock_timestamp()
    WHERE id = NEW.ticket_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

REVOKE EXECUTE ON FUNCTION public.trg_fn_support_ticket_messages_process() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_support_ticket_messages_process ON public.ticket_messages;
CREATE TRIGGER trg_support_ticket_messages_process
  AFTER INSERT ON public.ticket_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_support_ticket_messages_process();

-- 5. Storage Bucket & RLS Policies for ticket-attachments
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'ticket-attachments',
  'ticket-attachments',
  false,
  10485760, -- 10MB limit
  ARRAY['image/png', 'image/jpeg', 'image/webp', 'text/plain', 'application/json']
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp', 'text/plain', 'application/json'];

-- Storage RLS Policies for ticket-attachments
DROP POLICY IF EXISTS "Users can read own ticket attachments" ON storage.objects;
CREATE POLICY "Users can read own ticket attachments"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'ticket-attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can upload own ticket attachments" ON storage.objects;
CREATE POLICY "Users can upload own ticket attachments"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'ticket-attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can delete own ticket attachments" ON storage.objects;
CREATE POLICY "Users can delete own ticket attachments"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'ticket-attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
