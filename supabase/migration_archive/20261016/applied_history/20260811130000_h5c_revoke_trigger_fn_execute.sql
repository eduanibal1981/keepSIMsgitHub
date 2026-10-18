-- H5c — trg_fn_sync_offline_endpoints() was created SECURITY DEFINER with a
-- default ACL, which for a function means EXECUTE TO PUBLIC. That is exactly
-- what f0_grant_matrix_tests.sql T1/T3 exist to catch, and it caught it:
-- an anon caller could have invoked it directly.
--
-- Harmless in this instance (it takes no arguments and only re-copies primary
-- endpoint numbers into system_configs) but the rule is the rule — F6's
-- migration 20260717000200 revoked four trigger functions for the same reason.
-- Revoking EXECUTE does not stop the trigger: privilege is checked at
-- CREATE TRIGGER, not at fire time.
REVOKE ALL ON FUNCTION public.trg_fn_sync_offline_endpoints() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_fn_sync_offline_endpoints() TO service_role;
