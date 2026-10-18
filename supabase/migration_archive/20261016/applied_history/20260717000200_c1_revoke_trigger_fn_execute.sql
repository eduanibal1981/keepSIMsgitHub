-- C1 follow-up: trigger functions never need EXECUTE granted — they fire via
-- the trigger mechanism as the table owner. Revoke the default public grants so
-- they aren't callable through /rest/v1/rpc (clears the advisor findings the C1
-- triggers introduced). Applied live 2026-07-17.
REVOKE EXECUTE ON FUNCTION public.trg_fn_dispatch_notification() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_fn_notify_topup_result() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_fn_notify_wallet_credit() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_fn_notify_system_alert() FROM public, anon, authenticated;
