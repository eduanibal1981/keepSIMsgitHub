-- Run against an isolated pg_temp clone of the migration function. The runner
-- substitutes only table/function schemas; the production lookup body is used
-- unchanged. All fixtures and grants are rolled back, with no public writes.
INSERT INTO pg_temp.users(id) VALUES
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222'),
  ('33333333-3333-4333-8333-333333333333');
INSERT INTO pg_temp.profiles(id,full_name) SELECT id, 'Fixture account' FROM pg_temp.users;
SELECT set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
DO $tests$
DECLARE v jsonb;
BEGIN
  v := pg_temp.resolve_free_call_recipient('+201012345678');
  ASSERT v->>'status' = 'not_found', 'empty number must invite';
  ASSERT pg_temp.resolve_free_call_recipient('01012345678')->>'status' = 'invalid', 'national number blocked';
  INSERT INTO pg_temp.user_caller_ids VALUES ('22222222-2222-4222-8222-222222222222', '+201012345678', true);
  v := pg_temp.resolve_free_call_recipient('+201012345678');
  ASSERT v->>'status' = 'found' AND v->'recipient'->>'user_id' = '22222222-2222-4222-8222-222222222222', 'verified owner';
  ASSERT v->>'phone' = '+201012345678' AND v->'recipient'->>'phone' = '+201012345678', 'echo exact canonical destination';
  ASSERT (v->'recipient'->>'is_online')::boolean = false, 'no presence promise';
  ASSERT pg_temp.resolve_free_call_recipient('+9711012345678')->>'status' = 'not_found', 'no cross-country suffix';
  INSERT INTO pg_temp.virtual_did_numbers VALUES ('22222222-2222-4222-8222-222222222222', '+201012345678', 'active');
  ASSERT pg_temp.resolve_free_call_recipient('+201012345678')->>'status' = 'found', 'same owner deduplicated';
  INSERT INTO pg_temp.user_caller_ids VALUES ('33333333-3333-4333-8333-333333333333', '+201012345678', true);
  ASSERT pg_temp.resolve_free_call_recipient('+201012345678')->>'status' = 'ambiguous', 'two verified owners';
  DELETE FROM pg_temp.user_caller_ids WHERE user_id = '33333333-3333-4333-8333-333333333333';
  INSERT INTO pg_temp.sim_lines VALUES ('33333333-3333-4333-8333-333333333333', '+201012345678');
  ASSERT pg_temp.resolve_free_call_recipient('+201012345678')->>'status' = 'ambiguous', 'conflicting raw claim';
  DELETE FROM pg_temp.sim_lines;
  UPDATE pg_temp.users SET banned_until = now() + interval '1 day' WHERE id = '22222222-2222-4222-8222-222222222222';
  ASSERT pg_temp.resolve_free_call_recipient('+201012345678')->>'status' = 'unavailable', 'banned recipient';
  UPDATE pg_temp.users SET banned_until = null;
  INSERT INTO pg_temp.sim_lines VALUES ('33333333-3333-4333-8333-333333333333', '+96891234567');
  ASSERT pg_temp.resolve_free_call_recipient('+96891234567')->>'status' = 'unverified', 'raw SIM is not verified ownership';
  UPDATE pg_temp.profiles SET phone = '+96892345678' WHERE id = '33333333-3333-4333-8333-333333333333';
  ASSERT pg_temp.resolve_free_call_recipient('+96892345678')->>'status' = 'unverified', 'editable profile not verified ownership';
  INSERT INTO pg_temp.user_caller_ids VALUES ('33333333-3333-4333-8333-333333333333', '+96893456789', false);
  ASSERT pg_temp.resolve_free_call_recipient('+96893456789')->>'status' = 'not_found', 'unverified caller ID cannot identify account';
  INSERT INTO pg_temp.user_caller_ids VALUES ('11111111-1111-4111-8111-111111111111', '+96894567890', true);
  ASSERT pg_temp.resolve_free_call_recipient('+96894567890')->>'status' = 'self', 'own number cannot call';
  INSERT INTO pg_temp.virtual_did_numbers VALUES ('33333333-3333-4333-8333-333333333333', '+96895678901', 'inactive');
  ASSERT pg_temp.resolve_free_call_recipient('+96895678901')->>'status' = 'not_found', 'inactive DID excluded';
  UPDATE pg_temp.users SET phone = '96896789012', phone_confirmed_at = now() WHERE id = '33333333-3333-4333-8333-333333333333';
  ASSERT pg_temp.resolve_free_call_recipient('+96896789012')->>'status' = 'found', 'verified auth phone';
  ASSERT pg_temp.resolve_free_call_recipient(null, '22222222-2222-4222-8222-222222222222')->>'status' = 'unavailable', 'arbitrary route ID denied';
  INSERT INTO pg_temp.household_members VALUES ('11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', 'pending');
  ASSERT pg_temp.resolve_free_call_recipient(null, '22222222-2222-4222-8222-222222222222')->>'status' = 'unavailable', 'pending relationship denied';
  UPDATE pg_temp.household_members SET invite_status = 'accepted';
  ASSERT pg_temp.resolve_free_call_recipient(null, '22222222-2222-4222-8222-222222222222')->>'status' = 'found', 'accepted relationship';
  DELETE FROM pg_temp.household_members;
  INSERT INTO pg_temp.voip_call_sessions VALUES ('22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111111');
  ASSERT pg_temp.resolve_free_call_recipient(null, '22222222-2222-4222-8222-222222222222')->>'status' = 'found', 'known incoming peer';
  ASSERT pg_temp.resolve_free_call_recipient(null, '11111111-1111-4111-8111-111111111111')->>'status' = 'self', 'stable ID self';
  ASSERT pg_temp.resolve_free_call_recipient('+201012345678', '22222222-2222-4222-8222-222222222222')->>'status' = 'invalid', 'one input mode';
  PERFORM set_config('keepsims.test_quota', 'denied', true);
  ASSERT pg_temp.resolve_free_call_recipient('+201012345678')->>'status' = 'rate_limited', 'quota is enforced';
  PERFORM set_config('keepsims.test_quota', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  BEGIN
    PERFORM pg_temp.resolve_free_call_recipient('+201012345678');
    RAISE EXCEPTION 'Unauthenticated lookup accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  ASSERT NOT has_function_privilege('anon', 'pg_temp.resolve_free_call_recipient(text,uuid)', 'EXECUTE'), 'anon grant denied';
  ASSERT NOT has_function_privilege('service_role', 'pg_temp.resolve_free_call_recipient(text,uuid)', 'EXECUTE'), 'service grant denied';
  ASSERT has_function_privilege('authenticated', 'pg_temp.resolve_free_call_recipient(text,uuid)', 'EXECUTE'), 'authenticated grant retained';
END;
$tests$;
