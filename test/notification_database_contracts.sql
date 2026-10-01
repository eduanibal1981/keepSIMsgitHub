-- Run with notification crons paused. All fixtures are rolled back inside the
-- subtransaction; this script never invokes an external delivery provider.
DO $test$
DECLARE
  u uuid:=gen_random_uuid(); other_uid uuid:=gen_random_uuid();
  paid uuid:=gen_random_uuid(); basic uuid:=gen_random_uuid(); expired uuid:=gen_random_uuid(); foreign_line uuid:=gen_random_uuid(); draft uuid:=gen_random_uuid();
  n uuid; n2 uuid; nt uuid; schedule_id uuid; profile public.whatsapp_provider_profiles;
  country uuid; snapshot jsonb; a jsonb; b jsonb; target_claim jsonb; target_finish jsonb;
  jid uuid; bound jsonb; v_count integer; checks integer:=0; v_next timestamptz;
BEGIN
  BEGIN
    INSERT INTO auth.users(id,email,raw_user_meta_data,raw_app_meta_data)
      VALUES(u,'notification-fixture-'||u||'@example.invalid','{}','{}'),
        (other_uid,'notification-fixture-'||other_uid||'@example.invalid','{}','{}');
    INSERT INTO public.sim_lines(id,user_id,phone_number,plan_type,plan_expires_at,status,validity_expires_at)
      VALUES(paid,u,'+99900000001','standard',now()+interval '30 days','expired',now()-interval '1 day'),
        (basic,u,'+99900000002','free',NULL,'active',NULL),
        (expired,u,'+99900000003','premium',now()-interval '1 day','active',NULL),
        (foreign_line,other_uid,'+99900000004','premium',now()+interval '30 days','active',NULL);
    IF NOT public.notification_channel_eligible(u,paid,'whatsapp',NULL) THEN RAISE EXCEPTION 'Standard with expired carrier validity denied'; END IF;
    IF public.notification_channel_eligible(u,basic,'whatsapp',NULL) THEN RAISE EXCEPTION 'Basic borrowed paid entitlement'; END IF;
    IF public.notification_channel_eligible(u,expired,'email',NULL) THEN RAISE EXCEPTION 'Expired subscription allowed'; END IF;
    IF public.notification_channel_eligible(u,foreign_line,'whatsapp',NULL) THEN RAISE EXCEPTION 'Foreign line allowed'; END IF;
    IF public.notification_channel_eligible(u,NULL,'email',NULL) THEN RAISE EXCEPTION 'Account plan unlocked Email'; END IF;
    IF NOT public.notification_channel_eligible(u,NULL,'email','weekly_digest') THEN RAISE EXCEPTION 'Eligible paid digest denied'; END IF;
    checks:=checks+6;

    PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','app_metadata','{}'::jsonb)::text,true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.notification_channels(user_id,channel_type,is_enabled,config)
      VALUES(u,'whatsapp',true,'{"phone":"+20100000000"}')
      ON CONFLICT(user_id,channel_type) DO UPDATE SET is_enabled=true,config=excluded.config;
    IF NOT EXISTS(SELECT 1 FROM public.notification_channels WHERE user_id=u AND channel_type='whatsapp' AND is_enabled) THEN RAISE EXCEPTION 'Basic preference cannot be saved'; END IF;
    BEGIN
      INSERT INTO public.notifications(user_id,category,title,body) VALUES(u,'system','arbitrary','untrusted send');
      RAISE EXCEPTION 'Customer inserted arbitrary outbound notification';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN
      INSERT INTO public.notification_channels(user_id,channel_type,is_enabled,config) VALUES(u,'telegram',true,'{"chat_id":"123456"}');
      RAISE EXCEPTION 'Customer forged Telegram binding';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN
      PERFORM public.request_notification_event('line_added',foreign_line);
      RAISE EXCEPTION 'Customer produced event on foreign line';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    INSERT INTO public.sim_lines(id,user_id,phone_number,plan_type,plan_expires_at,notification_entitlement_verified)
      VALUES(draft,u,'+99900000005','standard',now()+interval '10 years',true);
    IF (SELECT notification_entitlement_verified FROM public.sim_lines WHERE id=draft) THEN RAISE EXCEPTION 'Customer forged paid verification on INSERT'; END IF;
    BEGIN
      UPDATE public.sim_lines SET notification_entitlement_verified=true WHERE id=draft;
      RAISE EXCEPTION 'Customer changed paid verification';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    nt:=public.request_notification_test('push',paid,0);
    IF (SELECT title FROM public.notifications WHERE id=nt)<>'KeepSIMs test alert' THEN RAISE EXCEPTION 'Test text not server-owned'; END IF;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims','{}',true);
    checks:=checks+7;

    IF public.notification_channel_eligible(u,draft,'whatsapp',NULL) THEN RAISE EXCEPTION 'Unpaid setup draft unlocked paid delivery'; END IF;
    INSERT INTO public.scheduled_topups(sim_line_id,user_id,amount,currency,frequency_days,next_execution_at,is_active,status,schedule_type)
      VALUES(draft,u,1,'USD',30,now()+interval '30 days',true,'active','notify');
    IF EXISTS(SELECT 1 FROM public.notification_dispatch_jobs j JOIN public.notifications n ON n.id=j.notification_id
      WHERE n.sim_line_id=draft AND j.payload->'channels' ? 'whatsapp') THEN RAISE EXCEPTION 'Draft setup queued paid channel'; END IF;
    INSERT INTO public.plan_payments(user_id,capture_id,kind,gross_usd,metadata,sim_line_id)
      VALUES(u,'notification-fixture-'||u,'plan',1,'{"plan":"standard"}',draft);
    IF NOT public.notification_channel_eligible(u,draft,'whatsapp',NULL) THEN RAISE EXCEPTION 'Finalized Standard plan did not unlock delivery'; END IF;
    IF (SELECT plan_expires_at FROM public.sim_lines WHERE id=draft)>now()+interval '367 days' THEN RAISE EXCEPTION 'Customer-provided plan duration survived finalization'; END IF;
    IF NOT EXISTS(SELECT 1 FROM public.notification_dispatch_jobs j JOIN public.notifications n ON n.id=j.notification_id
      WHERE n.sim_line_id=draft AND n.source_event_key LIKE '%:paid_confirmed' AND j.payload->'channels' ? 'whatsapp') THEN RAISE EXCEPTION 'Paid confirmation did not queue WhatsApp'; END IF;
    PERFORM public.emit_line_setup_event(u,draft,'line_added');
    IF (SELECT count(*) FROM public.notifications WHERE sim_line_id=draft AND source_event_key LIKE '%:paid_confirmed')<>1 THEN RAISE EXCEPTION 'Paid setup confirmation duplicated'; END IF;
    checks:=checks+6;

    -- Fixed one-time token binding and safe reuse rejection.
    INSERT INTO public.telegram_bind_tokens(token,user_id,expires_at) VALUES(md5(u::text),u,now()+interval '10 minutes');
    bound:=public.bind_telegram_bot_token(md5(u::text),'123456');
    IF bound->>'success'<>'true' OR NOT EXISTS(SELECT 1 FROM public.notification_channels WHERE user_id=u AND channel_type='telegram' AND config ? 'binding_verified_at') THEN RAISE EXCEPTION 'Verified binding missing'; END IF;
    IF public.bind_telegram_bot_token(md5(u::text),'789')->>'success'<>'false' THEN RAISE EXCEPTION 'Bind token reused'; END IF;
    checks:=checks+2;

    INSERT INTO public.notifications(user_id,sim_line_id,category,title,body,event_type,source_event_key)
      VALUES(u,paid,'line_critical','Fixture','Fixture','line_deactivation_imminent','fixture:'||u) RETURNING id INTO n;
    IF NOT EXISTS(SELECT 1 FROM public.notification_dispatch_jobs WHERE notification_id=n AND payload->'channels' ? 'whatsapp') THEN RAISE EXCEPTION 'Standard WhatsApp missing from outbox'; END IF;
    target_claim:=public.claim_notification_channel_target(n,'email','primary','{"email":"original@example.invalid"}');
    IF target_claim->>'claimed'<>'true' THEN RAISE EXCEPTION 'First target not claimed'; END IF;
    IF public.claim_notification_channel_target(n,'email','primary','{}')->>'claimed'<>'false' THEN RAISE EXCEPTION 'Parallel target reclaimed'; END IF;
    target_finish:=public.finish_notification_channel_target(n,'email','primary',(target_claim->>'claim_token')::uuid,'failed',true,'429');
    target_claim:=public.claim_notification_channel_target(n,'email','primary','{"email":"changed@example.invalid"}');
    IF target_claim->'target'->'snapshot'->>'email'<>'original@example.invalid' THEN RAISE EXCEPTION 'Retry snapshot changed'; END IF;
    PERFORM public.finish_notification_channel_target(n,'email','primary',(target_claim->>'claim_token')::uuid,'accepted_by_provider',false,'Accepted');
    IF public.claim_notification_channel_target(n,'email','primary','{}')->>'claimed'<>'false' THEN RAISE EXCEPTION 'Accepted target reclaimed'; END IF;
    SELECT id INTO jid FROM public.notification_dispatch_jobs WHERE notification_id=n;
    UPDATE public.notification_dispatch_jobs SET state='leased',attempt_count=1 WHERE id=jid;
    PERFORM public.finish_notification_dispatch_job(jid,'failed','known failure','{}',true);
    IF (SELECT state FROM public.notification_dispatch_jobs WHERE id=jid)<>'pending' THEN RAISE EXCEPTION 'Known failure not retried'; END IF;
    checks:=checks+6;

    SELECT p.* INTO profile FROM public.whatsapp_provider_profiles p
      JOIN public.whatsapp_country_routes r ON r.profile_id=p.id WHERE r.route_mode='baileys' AND p.is_enabled AND p.ready_state='ready' LIMIT 1;
    IF profile.id IS NULL THEN RAISE EXCEPTION 'No ready Baileys profile for routing fixture'; END IF;
    SELECT country_id INTO country FROM public.whatsapp_country_routes WHERE profile_id=profile.id AND route_mode='baileys' LIMIT 1;
    snapshot:=jsonb_build_object('purpose','subscription_alert','notification_id',n,'recipient_phone','+20100000000',
      'recipient_country_id',country,'sim_line_id',paid,'route_mode','baileys','profile_id',profile.id,
      'profile_version',profile.version,'sender_number',profile.expected_sender_number,'request','{}'::jsonb);
    a:=public.claim_whatsapp_message_attempt('fixture:'||u,snapshot);
    IF a->>'claimed'<>'true' THEN RAISE EXCEPTION 'First WhatsApp attempt denied'; END IF;
    IF public.claim_whatsapp_message_attempt('fixture:'||u,snapshot)->>'claimed'<>'false' THEN RAISE EXCEPTION 'Duplicate WhatsApp claimed'; END IF;
    IF NOT public.whatsapp_attempt_send_allowed((a->'attempt'->>'id')::uuid,profile.observed_sender_number) THEN RAISE EXCEPTION 'Owner-selected ready route denied'; END IF;
    INSERT INTO public.notifications(user_id,sim_line_id,category,title,body,event_type,source_event_key)
      VALUES(u,paid,'line_critical','Fixture two','Fixture','line_deactivation_imminent','fixture-two:'||u) RETURNING id INTO n2;
    b:=public.claim_whatsapp_message_attempt('fixture-two:'||u,snapshot||jsonb_build_object('notification_id',n2));
    IF b->>'reason'<>'cycle_quota_consumed' THEN RAISE EXCEPTION 'Cycle reservation duplicated'; END IF;
    UPDATE public.whatsapp_country_routes SET route_mode='disabled',profile_id=NULL WHERE country_id=country;
    IF public.whatsapp_attempt_send_allowed((a->'attempt'->>'id')::uuid,profile.observed_sender_number) THEN RAISE EXCEPTION 'Owner-disabled route allowed queued send'; END IF;
    PERFORM public.finish_whatsapp_message_attempt((a->'attempt'->>'id')::uuid,(a->>'claim_token')::uuid,'failed',true,'fixture','before send',NULL);
    b:=public.claim_whatsapp_message_attempt('fixture:'||u,snapshot||jsonb_build_object('profile_version',profile.version+1));
    IF b->>'reason'<>'route_changed' THEN RAISE EXCEPTION 'Retry silently switched profile'; END IF;
    checks:=checks+6;

    UPDATE public.whatsapp_message_attempts SET state='delivered',delivered_at=now() WHERE id=(a->'attempt'->>'id')::uuid;
    UPDATE public.whatsapp_message_attempts SET state='sent' WHERE id=(a->'attempt'->>'id')::uuid;
    IF (SELECT state FROM public.whatsapp_message_attempts WHERE id=(a->'attempt'->>'id')::uuid)<>'delivered' THEN RAISE EXCEPTION 'Delivered regressed'; END IF;
    IF NOT EXISTS(SELECT 1 FROM public.notifications WHERE id=n AND 'whatsapp'=ANY(delivered_via)) THEN RAISE EXCEPTION 'Receipt not projected'; END IF;
    checks:=checks+2;

    INSERT INTO public.scheduled_topups(sim_line_id,user_id,amount,currency,frequency_days,next_execution_at,is_active,status,schedule_type)
      VALUES(basic,u,1,'USD',30,now()-interval '2 days',true,'active','notify') RETURNING id INTO schedule_id;
    PERFORM public.process_due_notifications();
    SELECT next_execution_at INTO v_next FROM public.scheduled_topups WHERE id=schedule_id;
    PERFORM public.process_due_notifications();
    SELECT count(*) INTO v_count FROM public.notifications WHERE user_id=u AND source_event_key LIKE 'notify_due:'||schedule_id||':%';
    IF v_count<>1 OR v_next<=now() OR v_next>now()+interval '29 days' THEN RAISE EXCEPTION 'Scheduler duplicated or drifted'; END IF;
    checks:=checks+1;

    -- Intentional rollback of all fixture rows, schedules, route edits and jobs.
    RAISE EXCEPTION 'Rollback fixtures' USING ERRCODE='ZTEST';
  EXCEPTION WHEN SQLSTATE 'ZTEST' THEN NULL;
  END;
  PERFORM set_config('keepsims.notification_test_result',jsonb_build_object('passed',checks,'fixture_rollback',true)::text,true);
END $test$;
SELECT current_setting('keepsims.notification_test_result')::jsonb result;
