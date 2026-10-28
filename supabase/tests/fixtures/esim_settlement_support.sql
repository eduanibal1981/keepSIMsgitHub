-- Captured notification support shapes; no external sends.
CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    category text NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    is_read boolean DEFAULT false,
    action_url text,
    sim_line_id uuid,
    delivered_via text[] DEFAULT '{}'::text[],
    created_at timestamp with time zone DEFAULT now(),
    schema_version integer DEFAULT 1 NOT NULL,
    event_type text,
    source_event_key text,
    occurred_at timestamp with time zone DEFAULT now(),
    scheduled_at timestamp with time zone,
    expires_at timestamp with time zone,
    template_version integer DEFAULT 1,
    template_data jsonb DEFAULT '{}'::jsonb,
    target jsonb,
    CONSTRAINT notifications_category_check CHECK ((category = ANY (ARRAY['top_up_success'::text, 'top_up_failed'::text, 'top_up_reminder'::text, 'wallet_low'::text, 'wallet_depleted'::text, 'line_critical'::text, 'line_entering_grace'::text, 'geo_fence_triggered'::text, 'welcome_home_ready'::text, 'referral_reward'::text, 'system'::text, 'wallet_credit'::text, 'promo'::text, 'support'::text, 'esim_low_data'::text, 'carrier_action'::text, 'line_added'::text, 'line_setup_incomplete'::text, 'auto_recharge_scheduled'::text])))
);


CREATE TABLE public.alert_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    category text NOT NULL,
    is_enabled boolean DEFAULT true,
    channels text[] DEFAULT ARRAY['push'::text, 'email'::text, 'telegram'::text, 'whatsapp'::text],
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT alert_settings_category_check CHECK ((category = ANY (ARRAY['top_up_success'::text, 'top_up_failed'::text, 'wallet_low'::text, 'wallet_depleted'::text, 'line_critical'::text, 'line_entering_grace'::text, 'geo_fence_triggered'::text, 'welcome_home_ready'::text, 'referral_reward'::text, 'system'::text, 'wallet_credit'::text, 'promo'::text, 'support'::text, 'esim_low_data'::text, 'carrier_action'::text]))),
    CONSTRAINT alert_settings_channels_check CHECK ((channels <@ ARRAY['push'::text, 'email'::text, 'telegram'::text, 'whatsapp'::text, 'webhook'::text]))
);


CREATE TABLE public.notification_dispatch_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    notification_id uuid NOT NULL,
    user_id uuid NOT NULL,
    payload jsonb NOT NULL,
    state text DEFAULT 'pending'::text NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    next_attempt_at timestamp with time zone DEFAULT now() NOT NULL,
    lease_until timestamp with time zone,
    last_error text,
    response_summary jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    CONSTRAINT notification_dispatch_jobs_attempt_count_check CHECK ((attempt_count >= 0)),
    CONSTRAINT notification_dispatch_jobs_state_check CHECK ((state = ANY (ARRAY['pending'::text, 'leased'::text, 'complete'::text, 'unknown'::text, 'failed'::text, 'canceled'::text])))
);


CREATE TABLE public.user_preferences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    quiet_hours_start time without time zone,
    quiet_hours_end time without time zone,
    weekly_digest_enabled boolean DEFAULT true,
    travel_mode_enabled boolean DEFAULT false,
    biometric_enabled boolean DEFAULT false,
    transaction_pin_hash text,
    theme text DEFAULT 'system'::text,
    language text DEFAULT 'en'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    notification_timezone text,
    weekly_digest_consent_at timestamp with time zone,
    CONSTRAINT user_preferences_theme_check CHECK ((theme = ANY (ARRAY['light'::text, 'dark'::text, 'system'::text])))
);


CREATE TABLE public.notification_channels (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    channel_type text NOT NULL,
    is_enabled boolean DEFAULT true,
    config jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT notification_channels_channel_type_check CHECK ((channel_type = ANY (ARRAY['push'::text, 'email'::text, 'telegram'::text, 'sms'::text, 'whatsapp'::text, 'webhook'::text])))
);


CREATE TABLE public.notification_channel_catalog (
    channel_key text NOT NULL,
    label text NOT NULL,
    is_globally_enabled boolean DEFAULT true NOT NULL,
    provider text,
    credential_secret text,
    credential_status text DEFAULT 'unknown'::text NOT NULL,
    min_tier text DEFAULT 'basic'::text NOT NULL,
    user_configurable boolean DEFAULT true NOT NULL,
    monthly_quota integer,
    notes text,
    sort_order integer DEFAULT 100 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notification_channel_catalog_credential_status_check CHECK ((credential_status = ANY (ARRAY['configured'::text, 'missing'::text, 'unknown'::text]))),
    CONSTRAINT notification_channel_catalog_min_tier_check CHECK ((min_tier = ANY (ARRAY['basic'::text, 'standard'::text, 'premium'::text]))),
    CONSTRAINT paid_alert_channels_support_standard CHECK (((channel_key <> ALL (ARRAY['email'::text, 'whatsapp'::text])) OR (min_tier = 'standard'::text)))
);
