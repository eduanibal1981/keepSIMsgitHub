-- Isolated temp-table fixture, run with the real migration trigger body.
INSERT INTO pg_temp.user_caller_ids VALUES ('existing', '22222222-2222-4222-8222-222222222222', '+201012345678', true, now(), 'Personal', true);
SET LOCAL ROLE authenticated;
DO $test$ BEGIN
  BEGIN
    INSERT INTO pg_temp.user_caller_ids(id,user_id,phone_number,is_verified)
    VALUES ('forged','22222222-2222-4222-8222-222222222222','+96891234567',true);
    RAISE EXCEPTION 'Forged verification accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  INSERT INTO pg_temp.user_caller_ids(id,user_id,phone_number,is_verified)
  VALUES ('new','22222222-2222-4222-8222-222222222222','+96891234567',false);
  BEGIN
    UPDATE pg_temp.user_caller_ids SET is_verified=true WHERE id='new';
    RAISE EXCEPTION 'Client verification update accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    UPDATE pg_temp.user_caller_ids SET verified_at=now() WHERE id='new';
    RAISE EXCEPTION 'Client verification timestamp accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  UPDATE pg_temp.user_caller_ids SET label='Updated label',is_default=false WHERE id='existing';
  ASSERT (SELECT is_verified AND verified_at IS NOT NULL FROM pg_temp.user_caller_ids WHERE id='existing'), 'label/default change lost proof';
  UPDATE pg_temp.user_caller_ids SET phone_number='+96892345678' WHERE id='existing';
  ASSERT (SELECT NOT is_verified AND verified_at IS NULL FROM pg_temp.user_caller_ids WHERE id='existing'), 'phone change kept proof';
END $test$;
RESET ROLE;
UPDATE pg_temp.user_caller_ids SET is_verified=true,verified_at=now() WHERE id='new';
DO $test$ BEGIN
  ASSERT (SELECT is_verified FROM pg_temp.user_caller_ids WHERE id='new'), 'trusted server verification stopped';
END $test$;
