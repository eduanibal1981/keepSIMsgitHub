-- Standard and Premium line eligibility; delivery contract is repaired by the following migrations.
UPDATE public.notification_channel_catalog SET min_tier='standard' WHERE channel_key='whatsapp';
