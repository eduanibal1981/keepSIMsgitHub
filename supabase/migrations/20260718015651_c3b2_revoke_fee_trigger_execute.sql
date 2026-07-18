-- Trigger functions run as the table owner when the trigger fires; nothing
-- client-side should ever call them directly (advisor 0029).
REVOKE ALL ON FUNCTION public.calculate_topup_fees() FROM PUBLIC, anon, authenticated;