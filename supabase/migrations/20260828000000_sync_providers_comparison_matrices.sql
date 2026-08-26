-- =============================================================================
-- 20260828000000_sync_providers_comparison_matrices.sql
--
-- Synchronize carrier routing matrices, provider priorities, operator codes,
-- and USSD / helpline technical references across all 21 countries from
-- providersComparison_Tests.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Extend carrier_rules schema with USSD & Helpline technical references
-- -----------------------------------------------------------------------------
ALTER TABLE public.carrier_rules
  ADD COLUMN IF NOT EXISTS balance_check_ussd   text,
  ADD COLUMN IF NOT EXISTS recharge_ussd        text,
  ADD COLUMN IF NOT EXISTS customer_support_phone text;

COMMENT ON COLUMN public.carrier_rules.balance_check_ussd IS
  'USSD code or method to check prepaid balance, e.g. *166# or *121#';

COMMENT ON COLUMN public.carrier_rules.recharge_ussd IS
  'USSD format to manually recharge with a PIN voucher, e.g. *155*<PIN>#';

COMMENT ON COLUMN public.carrier_rules.customer_support_phone IS
  'Customer care phone number / IVR helpline, e.g. 900 or 101';

-- -----------------------------------------------------------------------------
-- 2. Update admin_update_carrier_rule RPC to accept new technical references
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_update_carrier_rule(
  p_carrier_id uuid,
  p_patch      jsonb,
  p_note       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_allowed text[] := ARRAY['minimum_topup_amount','recommended_topup_amount','topup_validity_days',
                            'inactivity_limit_days','grace_period_days','notes','inapp_pricing',
                            'offer_id','offer_value','sms_sender_ids','sms_balance_regex',
                            'sms_expiry_regex','sms_keywords','sms_language',
                            'activity_requirement','validity_qualifying_topup_amount',
                            'activity_requirement_note','balance_validity_days',
                            'refill_interval_days_override','rule_source_url',
                            'balance_check_ussd','recharge_ussd','customer_support_phone'];
  v_bad     text;
  v_before  jsonb;
  v_after   jsonb;
BEGIN
  PERFORM public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing to change' USING ERRCODE = 'KS467';
  END IF;

  SELECT string_agg(k, ', ') INTO v_bad
  FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Unknown field(s): %', v_bad USING ERRCODE = 'KS467';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.carriers WHERE id = p_carrier_id) THEN
    RAISE EXCEPTION 'Carrier % not found', p_carrier_id USING ERRCODE = 'KS461';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.carrier_rules WHERE carrier_id = p_carrier_id) THEN
    INSERT INTO public.carrier_rules
      (carrier_id, rule_type, inactivity_limit_days, minimum_topup_amount, topup_validity_days)
    VALUES
      (p_carrier_id, 'prepaid', 90, 1.00, 90);
  END IF;

  SELECT to_jsonb(cr) INTO v_before FROM public.carrier_rules cr WHERE cr.carrier_id = p_carrier_id;

  UPDATE public.carrier_rules SET
    minimum_topup_amount     = COALESCE(CASE WHEN p_patch ? 'minimum_topup_amount'
                                    THEN (p_patch ->> 'minimum_topup_amount')::numeric
                                    ELSE minimum_topup_amount END, minimum_topup_amount),
    recommended_topup_amount = CASE WHEN p_patch ? 'recommended_topup_amount'
                                    THEN (p_patch ->> 'recommended_topup_amount')::numeric
                                    ELSE recommended_topup_amount END,
    topup_validity_days      = COALESCE(CASE WHEN p_patch ? 'topup_validity_days'
                                    THEN (p_patch ->> 'topup_validity_days')::integer
                                    ELSE topup_validity_days END, topup_validity_days),
    inactivity_limit_days    = COALESCE(CASE WHEN p_patch ? 'inactivity_limit_days'
                                    THEN (p_patch ->> 'inactivity_limit_days')::integer
                                    ELSE inactivity_limit_days END, inactivity_limit_days),
    grace_period_days        = CASE WHEN p_patch ? 'grace_period_days'
                                    THEN (p_patch ->> 'grace_period_days')::integer
                                    ELSE grace_period_days END,
    inapp_pricing            = CASE WHEN p_patch ? 'inapp_pricing'
                                    THEN (p_patch ->> 'inapp_pricing')::numeric
                                    ELSE inapp_pricing END,
    offer_id                 = CASE WHEN p_patch ? 'offer_id'
                                    THEN NULLIF(btrim(p_patch ->> 'offer_id'), '')
                                    ELSE offer_id END,
    offer_value              = CASE WHEN p_patch ? 'offer_value'
                                    THEN (p_patch ->> 'offer_value')::bigint
                                    ELSE offer_value END,
    notes                    = CASE WHEN p_patch ? 'notes'
                                    THEN NULLIF(btrim(p_patch ->> 'notes'), '')
                                    ELSE notes END,
    sms_sender_ids           = CASE WHEN p_patch ? 'sms_sender_ids'
                                    THEN ARRAY(SELECT jsonb_array_elements_text(p_patch -> 'sms_sender_ids'))
                                    ELSE sms_sender_ids END,
    sms_balance_regex        = CASE WHEN p_patch ? 'sms_balance_regex'
                                    THEN NULLIF(btrim(p_patch ->> 'sms_balance_regex'), '')
                                    ELSE sms_balance_regex END,
    sms_expiry_regex         = CASE WHEN p_patch ? 'sms_expiry_regex'
                                    THEN NULLIF(btrim(p_patch ->> 'sms_expiry_regex'), '')
                                    ELSE sms_expiry_regex END,
    sms_keywords             = CASE WHEN p_patch ? 'sms_keywords'
                                    THEN ARRAY(SELECT jsonb_array_elements_text(p_patch -> 'sms_keywords'))
                                    ELSE sms_keywords END,
    sms_language             = CASE WHEN p_patch ? 'sms_language'
                                    THEN COALESCE(NULLIF(btrim(p_patch ->> 'sms_language'), ''), 'auto')
                                    ELSE sms_language END,
    balance_check_ussd       = CASE WHEN p_patch ? 'balance_check_ussd'
                                    THEN NULLIF(btrim(p_patch ->> 'balance_check_ussd'), '')
                                    ELSE balance_check_ussd END,
    recharge_ussd            = CASE WHEN p_patch ? 'recharge_ussd'
                                    THEN NULLIF(btrim(p_patch ->> 'recharge_ussd'), '')
                                    ELSE recharge_ussd END,
    customer_support_phone   = CASE WHEN p_patch ? 'customer_support_phone'
                                    THEN NULLIF(btrim(p_patch ->> 'customer_support_phone'), '')
                                    ELSE customer_support_phone END,
    last_verified_at         = now(),
    updated_at               = now()
  WHERE carrier_id = p_carrier_id;

  SELECT to_jsonb(cr) INTO v_after FROM public.carrier_rules cr WHERE cr.carrier_id = p_carrier_id;

  PERFORM public.admin_log(
    'carrier_rule.update', 'carrier_rule', p_carrier_id::text,
    v_before, v_after,
    COALESCE(p_note, 'via admin app')
  );

  RETURN jsonb_build_object('success', true, 'carrier_id', p_carrier_id, 'updated', v_after);
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. Ensure SELECT RLS policy on provider_offers
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'provider_offers' AND policyname = 'Authenticated can read provider offers'
  ) THEN
    CREATE POLICY "Authenticated can read provider offers" 
    ON public.provider_offers 
    FOR SELECT 
    TO authenticated 
    USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'provider_offers' AND policyname = 'Anyone can read active provider offers'
  ) THEN
    CREATE POLICY "Anyone can read active provider offers" 
    ON public.provider_offers 
    FOR SELECT 
    TO public 
    USING (true);
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 4. Add Onic Pakistan carrier if missing
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_pk_id uuid;
  v_onic_id uuid;
BEGIN
  SELECT id INTO v_pk_id FROM public.countries WHERE iso_code = 'PK';
  IF v_pk_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.carriers WHERE country_id = v_pk_id AND name ILIKE '%Onic%') THEN
      INSERT INTO public.carriers (country_id, name, fulfillment_gateway, is_supported, default_refill_amount)
      VALUES (v_pk_id, 'Onic Pakistan', 'API', true, 1.00)
      RETURNING id INTO v_onic_id;

      INSERT INTO public.carrier_rules (carrier_id, rule_type, inactivity_limit_days, grace_period_days, minimum_topup_amount, topup_validity_days, balance_check_ussd, customer_support_phone)
      VALUES (v_onic_id, 'prepaid', 180, 30, 0.44, 180, 'Onic App / *336#', 'hello@onic.pk / In-App');
    END IF;
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 4. Backfill USSD & Helpline technical references for carriers
-- -----------------------------------------------------------------------------

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*121# or *140#', balance_check_ussd),
       recharge_ussd = COALESCE('*120*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('101 / 800 101', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '28905875-2684-40a3-bdb5-8aef0497ea99';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*135#', balance_check_ussd),
       recharge_ussd = COALESCE('*135*<PIN># or *131*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('155 / 800 155', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '85fbac73-d5bd-460e-b4f4-68d49d66ed23';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('App-first / *135#', balance_check_ussd),
       recharge_ussd = COALESCE('*233*<PIN># or *611', recharge_ussd),
       customer_support_phone = COALESCE('In-App / 04 381 2222', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '821f233d-272c-4631-a3d2-e831ddf650c4';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*566# (Main Balance) / *121*1*2# (Data)', balance_check_ussd),
       recharge_ussd = COALESCE('*555*<16-digit PIN># / MyGP', recharge_ussd),
       customer_support_phone = COALESCE('121 / +8801701000121', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '26dacbcd-1733-4a9c-b468-3589a88597bf';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*222# (Main Balance) / *3# (Data)', balance_check_ussd),
       recharge_ussd = COALESCE('*123*<16-digit PIN># / My Robi', recharge_ussd),
       customer_support_phone = COALESCE('121 / +8801819400400', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'caafbd48-6451-44d1-9eb0-987af41e7739';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*124# (Main Balance) / *5000*500# (Data)', balance_check_ussd),
       recharge_ussd = COALESCE('*123*<16-digit PIN># / My Banglalink', recharge_ussd),
       customer_support_phone = COALESCE('121 / +8801911304121', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'b9cbc241-3650-41ab-b8c3-3c9612333dfb';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*152# (Main Balance) / *152*1# (Data)', balance_check_ussd),
       recharge_ussd = COALESCE('*151*<16-digit PIN># / MyTeletalk', recharge_ussd),
       customer_support_phone = COALESCE('121 / +8801500121121', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '4cdb1fd8-65b9-47e6-8626-c63e73878e84';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*778# (Main Balance) / *3# (Data)', balance_check_ussd),
       recharge_ussd = COALESCE('*123*<16-digit PIN># / My Airtel BD', recharge_ussd),
       customer_support_phone = COALESCE('121 / +8801678600786', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'b0597a41-8a01-477f-85ff-43458caf3243';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*122#', balance_check_ussd),
       recharge_ussd = COALESCE('*125*<PIN># / Call 111', recharge_ussd),
       customer_support_phone = COALESCE('196 / +973 1788 1111', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '2cb29ef4-a419-480a-8f5c-c109b5387fbe';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*142#', balance_check_ussd),
       recharge_ussd = COALESCE('*141*<PIN># / Zain App', recharge_ussd),
       customer_support_phone = COALESCE('107 / +973 3779 7995', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'afee691d-82be-4db4-97da-a6db2f18f8ec';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*124# / *142#', balance_check_ussd),
       recharge_ussd = COALESCE('*123*<PIN># / stc pay BH', recharge_ussd),
       customer_support_phone = COALESCE('124 / +973 3312 4124', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '3566da00-6c46-48f3-aafb-c8370bc5e12c';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*100# (Instant balance) / MeinMagenta App', balance_check_ussd),
       recharge_ussd = COALESCE('*101*<16-digit PIN># / Dial 2000', recharge_ussd),
       customer_support_phone = COALESCE('2202 / 0800 33 02202 / +49171882202', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'f3bd840a-bc97-4ae2-8206-e27f0cf94e56';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*100# (CallYa Balance) / MeinVodafone App', balance_check_ussd),
       recharge_ussd = COALESCE('*100*<16-digit PIN># / Dial 22922', recharge_ussd),
       customer_support_phone = COALESCE('0172 229 0 229 / +491722290229', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '34abfdf0-66c9-42f1-94eb-59e5219e6d8d';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*101# (Screen pop-up) / Mein O2 App', balance_check_ussd),
       recharge_ussd = COALESCE('*103*<16-digit PIN># / Dial 5667', recharge_ussd),
       customer_support_phone = COALESCE('0176 888 55 282 / +4917688855282', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '8e147f7a-60b7-45cc-8c32-5b7359007596';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*100# / congstar App', balance_check_ussd),
       recharge_ussd = COALESCE('*101*<16-digit CashCode># / Dial 9577', recharge_ussd),
       customer_support_phone = COALESCE('0221 79 700 700', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '7f12a660-ab11-47a2-bf13-6cd7a86bb51b';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*141# / SMS GUTHABEN to 55255', balance_check_ussd),
       recharge_ussd = COALESCE('*131*<16-digit PIN># / Dial 5588', recharge_ussd),
       customer_support_phone = COALESCE('5588 / 01806 532 272', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '8babd7c3-3cff-41a2-87c7-44e193831f78';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*131# (Screen pop-up)', balance_check_ussd),
       recharge_ussd = COALESCE('*131*<PIN># / Dial 321', recharge_ussd),
       customer_support_phone = COALESCE('322 / 069 945 199 322', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '3253ab0d-a79a-4e19-ac72-458c6a41b519';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*101# / Mein Blau App', balance_check_ussd),
       recharge_ussd = COALESCE('*103*<16-digit PIN># / Dial 1155', recharge_ussd),
       customer_support_phone = COALESCE('0177 177 1160', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '7b5c7719-b34b-4c51-a2c6-b486c6b90e67';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*100# / Ortel App', balance_check_ussd),
       recharge_ussd = COALESCE('*103*<16-digit PIN># / Dial 1155', recharge_ussd),
       customer_support_phone = COALESCE('1155 / 0177 177 1138', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '2652fd9d-22d8-4935-8aab-c84bcfe38026';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*100# / Mein Ay Yildiz App', balance_check_ussd),
       recharge_ussd = COALESCE('*100*<16-digit PIN># / Dial 1155', recharge_ussd),
       customer_support_phone = COALESCE('1155 / 0177 177 1177', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '51547096-c721-4d93-8bfc-489780c5fe4a';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*100# / Mein Otelo App', balance_check_ussd),
       recharge_ussd = COALESCE('*100*<16-digit PIN># / Dial 12430', recharge_ussd),
       customer_support_phone = COALESCE('0172 124 300', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '94231364-38c7-4bdf-9327-0d95c4a7a1af';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*101# / Fonic App', balance_check_ussd),
       recharge_ussd = COALESCE('*103*<16-digit PIN># / Dial 5667', recharge_ussd),
       customer_support_phone = COALESCE('0176 888 6423', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '70754905-9221-4142-a400-b68f51bdd78e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*101# / Tchibo Mobil App', balance_check_ussd),
       recharge_ussd = COALESCE('*103*<16-digit PIN># / Dial 4055', recharge_ussd),
       customer_support_phone = COALESCE('040 55 55 55 40', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'cc280785-dcd2-4f7c-9855-c8eba807808e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*100# / klarmobil App', balance_check_ussd),
       recharge_ussd = COALESCE('*101*<PIN># (Telekom) / *100*<PIN># (VF)', recharge_ussd),
       customer_support_phone = COALESCE('040 34 8585 300', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '88e44ab2-2e75-4159-8695-e35937f70b7d';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*100# / BILDmobil Portal', balance_check_ussd),
       recharge_ussd = COALESCE('*100*<16-digit PIN># / Dial 2142', recharge_ussd),
       customer_support_phone = COALESCE('01805 88 00 88', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '55100b54-dc63-4838-bba0-44fea2bae915';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('1&1 Control-Center App / Portal', balance_check_ussd),
       recharge_ussd = COALESCE('Web Recharge / Automatic Bank SEPA', recharge_ussd),
       customer_support_phone = COALESCE('0721 96 00', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'ef7b1cb4-9c87-433f-bb63-39250884f2f2';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*222# (Airtime) / *600# (PixX Bundles)', balance_check_ussd),
       recharge_ussd = COALESCE('*111*<PIN># or *222*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('666 / +21323921313', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '882272bc-6600-40ab-be8e-1cac32b777b2';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*710# (Airtime) / *707# (Hayla/Special)', balance_check_ussd),
       recharge_ussd = COALESCE('*700*<PIN># or *710*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('777 / +213770850005', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'b25621ff-7000-4fbe-9e41-eb6888f17554';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*200# (Airtime) / *151# (MAXY/Haya)', balance_check_ussd),
       recharge_ussd = COALESCE('*115*<PIN># or *200*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('333 / +213554500507', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'ef94a579-d459-411e-b806-cbd2bf8d5db6';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*868*1# or *60#', balance_check_ussd),
       recharge_ussd = COALESCE('*858*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('888 / 16888 / +20101888888', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '08ccb7e2-52a0-4002-ad88-672a517cba4f';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*100*3# or #100#', balance_check_ussd),
       recharge_ussd = COALESCE('*102*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('110 / 16110 / +201223202020', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '72d2fd98-a319-493f-8ee0-2c079530a9ac';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*888# or *555#', balance_check_ussd),
       recharge_ussd = COALESCE('*556*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('333 / 01111234333', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '3c51f2ca-1e38-44d1-b777-4b08e9316e5c';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*550#', balance_check_ussd),
       recharge_ussd = COALESCE('*555*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('111 / 19777 / +201555000111', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'e196d805-eecc-4c46-a937-df3140688f6e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('Dial 1299 (SMS) or *333#', balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('198 / 199 / +919888898888', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*121# or *123#', balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('121 / 198 / +919810198101', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'd34d491a-cbc8-4a31-901b-0b2279bb73c0';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*199# or *111#', balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('199 / 198 / +919820098200', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '0114b343-003e-4a2a-a4ae-8daabe73e5dd';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*123# or *124#', balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('1503 / 1800-180-1503', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '1e07e23c-b088-4ded-9a3c-fc41d3e46f97';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*444# or *123#', balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('1500 / 1800-22-1500', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'ba06511f-05c6-4922-9ae9-3536b71bba27';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*133# or *211#', balance_check_ussd),
       recharge_ussd = COALESCE('*133*<PIN># or call 333', recharge_ussd),
       customer_support_phone = COALESCE('111 / 07701110000 / +9647701110000', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '8fcac8eb-0992-4690-8041-069d142b1c8b';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*100# or *200#', balance_check_ussd),
       recharge_ussd = COALESCE('*101*<PIN># or call 216', recharge_ussd),
       customer_support_phone = COALESCE('107 / 07802999107 / +9647802999107', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '580f8049-0cb9-4033-a77e-e71aaf670380';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*211#', balance_check_ussd),
       recharge_ussd = COALESCE('*221*<PIN># or call 321 / 221', recharge_ussd),
       customer_support_phone = COALESCE('411 / 07500000411 / +9647500000411', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '8824c4dd-1be1-4f87-b2bc-a3a4738fd373';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*116# / *121#', balance_check_ussd),
       recharge_ussd = COALESCE('*114*<PIN># / Zain App', recharge_ussd),
       customer_support_phone = COALESCE('1234 / +962 79 000 1234', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '490a2b23-efda-4d06-9317-9ff7b9e1ddfa';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*155# / *150#', balance_check_ussd),
       recharge_ussd = COALESCE('*150*<PIN># / Orange App', recharge_ussd),
       customer_support_phone = COALESCE('1777 / +962 77 770 0177', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '8568531b-26eb-4793-ab44-e1d80c027abf';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*136# / *100#', balance_check_ussd),
       recharge_ussd = COALESCE('*133*<PIN># / Call 1331', recharge_ussd),
       customer_support_phone = COALESCE('1333 / +962 78 800 1333', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'bd2761bb-020a-4fd7-857c-cc8e4292f330';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*142# or *107#', balance_check_ussd),
       recharge_ussd = COALESCE('*141*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('107 / +965 97107107', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '2ef9b656-cef7-447e-9c04-80cda1baaa19';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*121# or *555#', balance_check_ussd),
       recharge_ussd = COALESCE('*111*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('121 / +965 1805555', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'e4a22bc3-4b05-4e16-a428-cc40b269da78';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*555# or *100#', balance_check_ussd),
       recharge_ussd = COALESCE('*500*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('102 / +965 55102102', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'f993b9d0-9974-4986-9eb2-8b0f2e867db7';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*102# or App', balance_check_ussd),
       recharge_ussd = COALESCE('*500*<PIN># or App', recharge_ussd),
       customer_support_phone = COALESCE('1789 / +965 51001789', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '559c8e3d-bc5a-4e52-a0be-ae20bd28ec6e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*220# or *111# / SMS to 1144 / touch App', balance_check_ussd),
       recharge_ussd = COALESCE('*200*<14-digit PIN># or *220*<PIN># / touch App', recharge_ussd),
       customer_support_phone = COALESCE('111 / +9613792111 / 1788', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'a6ae78e4-cff0-4fb0-af4a-ec57e2b2e942';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*111# or *140# / SMS to 1050 / Alfa App', balance_check_ussd),
       recharge_ussd = COALESCE('*141*<14-digit PIN># or Alfa App', recharge_ussd),
       customer_support_phone = COALESCE('111 / +9613391111 / +9613030000', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '5e058bd4-2db8-4dd5-9d1e-ce7443c24218';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('#456# (Balance) / #123# (Portal) / #678# (Data)', balance_check_ussd),
       recharge_ussd = COALESCE('*123*<14-digit PIN># / MyDialog', recharge_ussd),
       customer_support_phone = COALESCE('1777 / +94777678678', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '71785c0a-4d93-4d31-a2ad-58778dfe21de';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('#141# (Balance) / *141*1*1# (Data) / #888#', balance_check_ussd),
       recharge_ussd = COALESCE('*102*<14-digit PIN># / SelfCare', recharge_ussd),
       customer_support_phone = COALESCE('1717 / +94712755777', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'd9a33c0d-e27e-4ff5-864d-f8cb3c52bb9a';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*344# (Main Portal) / *131# (Data)', balance_check_ussd),
       recharge_ussd = COALESCE('*102*<16-digit PIN># / Hutch App', recharge_ussd),
       customer_support_phone = COALESCE('1788 / +94785785785', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '090ef88f-0358-43ed-a866-b0669964a772';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*550# (Legacy) / #456# (Dialog Menu)', balance_check_ussd),
       recharge_ussd = COALESCE('*555*<PIN># / *123*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1755 / +94755555555', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '7731b015-3681-4543-b557-9785665c0f73';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('#580# (Airtime) / #554# (Passes)', balance_check_ussd),
       recharge_ussd = COALESCE('*444*<PIN># or *555*<PIN>*3# (Pass *3)', recharge_ussd),
       customer_support_phone = COALESCE('888 / +212537719000', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '98d1acf2-5615-4008-bfb5-abf95dc22edc';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('#554# (Balance & Validity)', balance_check_ussd),
       recharge_ussd = COALESCE('*120*<PIN># or *120*<PIN>*3# (Pass *3)', recharge_ussd),
       customer_support_phone = COALESCE('121 / +212663121121', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '223bb67b-843a-4b54-829e-6a91a720bf47';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*120*30# or *120*1# (Balance & Validity)', balance_check_ussd),
       recharge_ussd = COALESCE('*120*20*<PIN># or *120*20*<PIN>*3# (Pass *3)', recharge_ussd),
       customer_support_phone = COALESCE('220 / +212529000220', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'd10adfd9-ee64-43b1-abe3-3d54373d5c4c';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*901# or *101# (Balance & Validity) / *901# (Data)', balance_check_ussd),
       recharge_ussd = COALESCE('*902*<16-digit PIN># or *102*<PIN># / Ncell App', recharge_ussd),
       customer_support_phone = COALESCE('9005 (Ncell) / 9805554444 / +9779805554444', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*400# (Direct Balance & Expiry Date) / *1415# (Offers)', balance_check_ussd),
       recharge_ussd = COALESCE('*412*<14-digit PIN># / Namaste App', recharge_ussd),
       customer_support_phone = COALESCE('1498 (NTC Mobile) / 197 / +97714221197', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '6a49574b-b1fa-4a1b-85bc-b9595bb5bda4';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*102# *(Legacy)*', balance_check_ussd),
       recharge_ussd = COALESCE('*122*<PIN># *(Legacy)*', recharge_ussd),
       customer_support_phone = COALESCE('*(Non-operational)*', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'b2b70951-371d-4cf2-ab68-401c57498aec';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*100#', balance_check_ussd),
       recharge_ussd = COALESCE('*101*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1234 / +96824241234', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '8e789341-fe2a-402c-842c-0d769ccfc516';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*141# / *102#', balance_check_ussd),
       recharge_ussd = COALESCE('*115*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1500 / +96895011500', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '6c575769-c34a-46b8-865d-398be2088e24';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*777# / App', balance_check_ussd),
       recharge_ussd = COALESCE('*777*<PIN># / In-App', recharge_ussd),
       customer_support_phone = COALESCE('1771 / +96877101771', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'd5a330e3-888f-4ae7-a487-c70ba3435abb';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*139#', balance_check_ussd),
       recharge_ussd = COALESCE('*138*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('98400000 / 1600', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '02ba945c-9479-48d4-9852-7cc5030ccede';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*181*2#', balance_check_ussd),
       recharge_ussd = COALESCE('*180*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1240 / 180 (IVR)', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '67ae4e83-9b19-4168-9140-a83ccb0af44b';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*600*11#', balance_check_ussd),
       recharge_ussd = COALESCE('*600*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1234 / 1233 (IVR)', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '76923a26-bb55-497a-8da8-b2248f8fcc0f';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*111# (0.24 PKR fee) / Jazz World App', balance_check_ussd),
       recharge_ussd = COALESCE('*123*<14-digit PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('111 / 042-111-300-300 / +923000000111', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'ed074f20-1809-4665-abfe-9c571d11b4e3';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*444# (0.24 PKR fee) / My Telenor App', balance_check_ussd),
       recharge_ussd = COALESCE('*555*<14-digit PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('345 / 042-111-345-100 / +923451111345', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '1b30419d-d8cc-4e5c-ba69-69ad1db1d827';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*222# (0.24 PKR fee) / My Zong App', balance_check_ussd),
       recharge_ussd = COALESCE('*101*<14-digit PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('310 / 051-111-222-111 / +923101111310', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'd11255ef-6919-4280-91bd-70199fba5253';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*124# (0.24 PKR fee) / My Ufone App', balance_check_ussd),
       recharge_ussd = COALESCE('*333*<14-digit PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('333 / 051-111-333-100 / +923331111333', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'c9610c03-e9b0-4652-824e-05819c750434';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*143# or text BAL to 222', balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('211 / (02) 7730-1000', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*123# or text BAL to 214', balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('*888 / (02) 8888-1111', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'f259b40b-3d06-4fb2-b765-edb0d01df788';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*185# or via DITO App', balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('185 / (02) 8888-3486', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '0ca2d774-fca1-4d2f-845a-f38babee4adc';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*143# or text BAL to 222', balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('808 / (02) 7730-1500', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'dce6f8a2-bdf1-4e37-be40-7db94d97b4de';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*123# or text BAL to 214', balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('*888 / (02) 8888-1111', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '8d3b02aa-f69b-4f06-ab39-c6edb703f875';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*129# (Main Balance) / *129*1# (Data) / SMS Balance to 121', balance_check_ussd),
       recharge_ussd = COALESCE('*127*<14-digit PIN># / Ooredoo App', recharge_ussd),
       customer_support_phone = COALESCE('111 / +97444200700 / 170', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'a6afbb6c-9a9e-4af5-8b4e-c40b87ceb4cb';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*129# (Main Balance) / *100# (Data Menu) / My Vodafone App', balance_check_ussd),
       recharge_ussd = COALESCE('*127*<PIN># / *233*<PIN># / Dial 111', recharge_ussd),
       customer_support_phone = COALESCE('111 / +97470000111 / 8007111', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '6a16b6f7-6036-4c96-b928-be8b286442fc';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*166#', balance_check_ussd),
       recharge_ussd = COALESCE('*155*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1500 / 900', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'da1c57b4-5276-4814-ade4-1d5a421bc29e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*1411#', balance_check_ussd),
       recharge_ussd = COALESCE('*1400*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1100', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'efc1729e-3fbb-43c1-8297-37754732aeed';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*142#', balance_check_ussd),
       recharge_ussd = COALESCE('*141*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('959', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'a03cee64-eea7-4ec7-a234-dc8a625a354e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*102#', balance_check_ussd),
       recharge_ussd = COALESCE('*101*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1789', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'ec524833-a098-4ca9-b9a4-e361cb8ecf92';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*110#', balance_check_ussd),
       recharge_ussd = COALESCE('*111*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1755', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '781ff056-c52f-4e96-a678-718ac1c6b647';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*102#', balance_check_ussd),
       recharge_ussd = COALESCE('*101*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('166000', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '8588a637-a0c9-41f7-a4fd-9fe4197f6171';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*106#', balance_check_ussd),
       recharge_ussd = COALESCE('*104*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1101', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'fab6caff-713a-4338-a14c-872c1a17cc3e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*588#', balance_check_ussd),
       recharge_ussd = COALESCE('*1588*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('950', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'b09e42c4-e66f-4ab6-b7e5-70ab35ca6fbb';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*123# (Screen Pop-up) / Turkcell App', balance_check_ussd),
       recharge_ussd = COALESCE('*122*<16-digit PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('532 / 0532 532 00 00 / +905325320000', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'fe1eb878-c1d2-4a01-8510-7f938c73712e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*123# / SMS OZET to 7000', balance_check_ussd),
       recharge_ussd = COALESCE('*111*<12-digit PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('542 / 0542 542 00 00 / +905425420000', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '8c132d25-bcd4-4764-83ee-15f63924f665';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*123# / SMS TL to 9333', balance_check_ussd),
       recharge_ussd = COALESCE('*9333# / bimcell.com.tr', recharge_ussd),
       customer_support_phone = COALESCE('551 / 444 4 551 / +905515510000', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '181f1aa0-41a6-4221-baa2-f62b63a1b64e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*123# / SMS TL to 9333', balance_check_ussd),
       recharge_ussd = COALESCE('*9333# / pttcell.com.tr', recharge_ussd),
       customer_support_phone = COALESCE('444 1 788 / +904441788', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '3e9caec3-6125-4aa8-b01f-512a3fe88c18';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*123# (Screen Pop-up)', balance_check_ussd),
       recharge_ussd = COALESCE('*111*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('542 / +905428880542', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'f7c51a5c-4bb2-4005-9152-4baca61018bf';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*121# or *140# | **Recharge USSD:** *120*<PIN># | **Customer Care:** 101 / 800 101', balance_check_ussd),
       recharge_ussd = COALESCE('*120*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE(NULL, customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '28905875-2684-40a3-bdb5-8aef0497ea99';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE('*233*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE(NULL, customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '821f233d-272c-4631-a3d2-e831ddf650c4';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('121 (From Banglalink) / +8801911304121 / 01911304121', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'b9cbc241-3650-41ab-b8c3-3c9612333dfb';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('121 (From GP) / +8801701000121 / 01701000121', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '26dacbcd-1733-4a9c-b468-3589a88597bf';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('121 (From Robi) / +8801819400400 / 01819400400', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'caafbd48-6451-44d1-9eb0-987af41e7739';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('Dial 0721 96 00 (Free from 1&1 mobile)', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'ef7b1cb4-9c87-433f-bb63-39250884f2f2';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE('Dial *100*<16-digit Aufladecode># / Dial 1155 / Web: https://www.ayyildiz.de/guthaben-aufladen', recharge_ussd),
       customer_support_phone = COALESCE('Dial 1155 (From Ay Yildiz mobile) / 0177 177 1177 / +49 177 1771177', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '51547096-c721-4d93-8bfc-489780c5fe4a';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE('Dial *100*<16-digit Aufladecode># / Dial 2142 / Web: https://www.bildmobil.de/aufladen.html', recharge_ussd),
       customer_support_phone = COALESCE('Dial 01805 88 00 88 (Vodafone D2 Network)', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '55100b54-dc63-4838-bba0-44fea2bae915';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE('Dial *103*<16-digit Aufladecode># / Dial 1155 / Web: https://www.blau.de/service/guthaben-aufladen/', recharge_ussd),
       customer_support_phone = COALESCE('Dial 0177 177 1160 (Mon–Fri 07:00–20:00, Sat 10:00–18:00)', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '7b5c7719-b34b-4c51-a2c6-b486c6b90e67';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE('Dial *101*<16-digit CashCode># / Dial 9577 / Web: https://www.congstar.de/prepaid/services/guthaben-aufladen/', recharge_ussd),
       customer_support_phone = COALESCE('Dial 0221 79 700 700 (Mon–Sat 08:00–22:00)', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '7f12a660-ab11-47a2-bf13-6cd7a86bb51b';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE('Dial *103*<16-digit Aufladenummer># / Dial 5667 / Web: https://www.fonic.de/service/aufladen', recharge_ussd),
       customer_support_phone = COALESCE('Dial 0176 888 6423', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '70754905-9221-4142-a400-b68f51bdd78e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE('Dial *101*<PIN># (Telekom network SIMs) / *100*<PIN># (Vodafone network SIMs) / Web: https://www.klarmobil.de/service/guthaben-aufladen/', recharge_ussd),
       customer_support_phone = COALESCE('Dial 040 34 8585 300', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '88e44ab2-2e75-4159-8695-e35937f70b7d';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE('Dial *103*<16-digit Code># / Dial 1155 / Web: https://www.ortelmobile.de/guthaben-aufladen.html', recharge_ussd),
       customer_support_phone = COALESCE('Dial 1155 (From Ortel mobile) / 0177 177 1138 / +49 177 1771138', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '2652fd9d-22d8-4935-8aab-c84bcfe38026';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE('Dial *100*<16-digit Code># / Dial 12430 / Web: https://www.otelo.de/prepaid/aufladen', recharge_ussd),
       customer_support_phone = COALESCE('Dial 0172 124 300 / +49 172 124300', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '94231364-38c7-4bdf-9327-0d95c4a7a1af';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE('Dial *103*<16-digit Aufladecode># / Dial 4055 / Web: https://www.tchibo-mobil.de/aufladen', recharge_ussd),
       customer_support_phone = COALESCE('Dial 040 55 55 55 40 (Mon–Sat 08:00–22:00)', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'cc280785-dcd2-4f7c-9855-c8eba807808e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE('Dial *101*<16-digit CashCode># / Dial 2000 (Follow IVR voice prompt) / Web: https://www.telekomaufladen.de/', recharge_ussd),
       customer_support_phone = COALESCE('Dial 2202 (Free from Telekom mobile) / 0800 33 02202 / +49 171 88 2202', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'f3bd840a-bc97-4ae2-8206-e27f0cf94e56';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*121# or *123# | **Customer Care:** 121 / 198 / +919810198101', balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE(NULL, customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'd34d491a-cbc8-4a31-901b-0b2279bb73c0';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*123# or *124# | **Customer Care:** 1503 / 1800-180-1503', balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE(NULL, customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '1e07e23c-b088-4ded-9a3c-fc41d3e46f97';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('198 (Complaints) / 199 (General) / +919888898888', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('*133# or *211# | **Recharge USSD:** *133*<14_digit_PIN># or call 333 | **Customer Care:** 111 (from mobile) / 07701110000 / +9647701110000', balance_check_ussd),
       recharge_ussd = COALESCE('*133*<14_digit_PIN>#', recharge_ussd),
       customer_support_phone = COALESCE(NULL, customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '8fcac8eb-0992-4690-8041-069d142b1c8b';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('1333 (from Umniah) / +962 78 800 1333 (International / Local)', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'bd2761bb-020a-4fd7-857c-cc8e4292f330';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('1777 (Local Dialog) / +94777678678 / 0777678678', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '71785c0a-4d93-4d31-a2ad-58778dfe21de';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('Dial *120*30# or *120*1# (Balance & Validity)', balance_check_ussd),
       recharge_ussd = COALESCE('Dial *120# (Self-care Menu) or *120*20*<PIN>#:', recharge_ussd),
       customer_support_phone = COALESCE('220 (From Inwi) / 0529 000 220 / +212 529 000 220', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'd10adfd9-ee64-43b1-abe3-3d54373d5c4c';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('9005 (From Ncell) / 9805554444 / +9779805554444', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('1240 / +96893001240', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '67ae4e83-9b19-4168-9140-a83ccb0af44b';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('111 / 042-111-300-300 / +923000000111', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'ed074f20-1809-4665-abfe-9c571d11b4e3';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('345 / 042-111-345-100 / +923451111345', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '1b30419d-d8cc-4e5c-ba69-69ad1db1d827';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('333 / 051-111-333-100 / +923331111333', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'c9610c03-e9b0-4652-824e-05819c750434';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('310 / 051-111-222-111 / +923101111310', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'd11255ef-6919-4280-91bd-70199fba5253';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('185 (DITO Mobile) / (02) 8888-3486 / +63288883486', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '0ca2d774-fca1-4d2f-845a-f38babee4adc';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('211 (Mobile) / (02) 7730-1000 / +63277301000', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('*888 (Mobile) / (02) 8888-1111 / +63288881111', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'f259b40b-3d06-4fb2-b765-edb0d01df788';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('444 1 788 / +904441788', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '3e9caec3-6125-4aa8-b01f-512a3fe88c18';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE(NULL, balance_check_ussd),
       recharge_ussd = COALESCE(NULL, recharge_ussd),
       customer_support_phone = COALESCE('532 (From Turkcell) / 0532 532 00 00 / +905325320000', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'fe1eb878-c1d2-4a01-8510-7f938c73712e';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('Dial *100# (Main Account Balance & Expiration), *100*1# (Detailed Balance), *124# (Internet & Forfait Balance)', balance_check_ussd),
       recharge_ussd = COALESCE('Dial *101*<PIN># or *100*2*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1111 (From Ooredoo) / +216 22 11 11 11', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '27a7a925-1af0-4697-b39e-f0a12a8c131b';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('Dial *111# or *111*1# (Main Airtime Balance & Expiration), *124# (Internet Passes & Pass Mix)', balance_check_ussd),
       recharge_ussd = COALESCE('Dial *100*<PIN># or *111*2*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1150 (From Mobile) / +216 31 11 11 50', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = 'e6f8679a-7232-4981-9e39-abcae5009f6f';

UPDATE public.carrier_rules
   SET balance_check_ussd = COALESCE('Dial *122# (Main Airtime Balance & Expiration), *122*2# (Internet & Forfait Balance), *122*3# (Bonus Minutes/Data)', balance_check_ussd),
       recharge_ussd = COALESCE('Dial *123*<PIN>#', recharge_ussd),
       customer_support_phone = COALESCE('1298 (From Mobile) / 1198 (Fixed Line) / +216 71 00 12 98', customer_support_phone),
       updated_at = now()
 WHERE carrier_id = '2ae782fb-66db-4471-b773-bfee4a5d7707';

-- -----------------------------------------------------------------------------
-- 5. Synchronize Carrier Provider Mappings (Priority, Primary, Enablement, Codes)
-- -----------------------------------------------------------------------------

-- Mapping: [AE] Etisalat (e&) -> reloadly (Code: 1100, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '28905875-2684-40a3-bdb5-8aef0497ea99' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '28905875-2684-40a3-bdb5-8aef0497ea99', 'reloadly', 'AE', 'AE',
    '1100', '1100', 10, true, true, 'Reloadly (`1100`) • SKU: `rl_1100_3.11` (10 AED) • Cost: $3.11 USD ($3.02 net) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Etisalat (e&) -> zendit (Code: Etisalat, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '28905875-2684-40a3-bdb5-8aef0497ea99' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '28905875-2684-40a3-bdb5-8aef0497ea99', 'zendit', 'AE', 'AE',
    'Etisalat', 'Etisalat', 20, false, true, 'Zendit (`Etisalat`) • Offer: `ETISALAT_AE_10_AED` (10 AED) • Cost: $3.27 USD ($3.08 net) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Etisalat (e&) -> dtone (Code: 2097, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '28905875-2684-40a3-bdb5-8aef0497ea99' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '28905875-2684-40a3-bdb5-8aef0497ea99', 'dtone', 'ARE', 'ARE',
    '2097', '2097', 30, false, true, 'DT One (`2097`) • Product: `13199` (10 AED Direct / PIN) • Cost: 1.278 OMR ($3.32 USD) • Delivery: Direct / PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Etisalat (e&) -> ding (Code: ETAE, Priority: 40, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '28905875-2684-40a3-bdb5-8aef0497ea99' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '28905875-2684-40a3-bdb5-8aef0497ea99', 'ding', 'AE', 'AE',
    'ETAE', 'ETAE', 40, false, true, 'DingConnect (`ETAE`) • SKU: `ETAEE7322` (10 AED) • Cost: 1.08 OMR ($2.81 USD) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] du -> reloadly (Code: 529, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '85fbac73-d5bd-460e-b4f4-68d49d66ed23' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '85fbac73-d5bd-460e-b4f4-68d49d66ed23', 'reloadly', 'AE', 'AE',
    '529', '529', 10, true, true, 'Reloadly (`529`) • SKU: `rl_529_2.72` (10 AED) • Cost: $2.72 USD ($2.67 net) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] du -> zendit (Code: du, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '85fbac73-d5bd-460e-b4f4-68d49d66ed23' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '85fbac73-d5bd-460e-b4f4-68d49d66ed23', 'zendit', 'AE', 'AE',
    'du', 'du', 20, false, true, 'Zendit (`du`) • Offer: `DU_AE_10_AED` (10 AED) • Cost: $3.27 USD ($3.08 net) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] du -> dtone (Code: 2098, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '85fbac73-d5bd-460e-b4f4-68d49d66ed23' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '85fbac73-d5bd-460e-b4f4-68d49d66ed23', 'dtone', 'ARE', 'ARE',
    '2098', '2098', 30, false, true, 'DT One (`2098`) • Product: `13207` (10 AED Direct / PIN) • Cost: 1.278 OMR ($3.32 USD) • Delivery: Direct / PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] du -> ding (Code: DUAE, Priority: 40, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '85fbac73-d5bd-460e-b4f4-68d49d66ed23' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '85fbac73-d5bd-460e-b4f4-68d49d66ed23', 'ding', 'AE', 'AE',
    'DUAE', 'DUAE', 40, false, true, 'DingConnect (`DUAE`) • SKU: `DUAE5117` (10 AED) • Cost: 1.08 OMR ($2.81 USD) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Virgin Mobile UAE -> reloadly (Code: 1155, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '821f233d-272c-4631-a3d2-e831ddf650c4' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '821f233d-272c-4631-a3d2-e831ddf650c4', 'reloadly', 'AE', 'AE',
    '1155', '1155', 10, true, true, 'Reloadly (`1155`) • SKU: `rl_1155_6.1` (20 AED PIN) • Cost: $6.10 USD ($5.98 net) • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Virgin Mobile UAE -> dtone (Code: 3392, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '821f233d-272c-4631-a3d2-e831ddf650c4' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '821f233d-272c-4631-a3d2-e831ddf650c4', 'dtone', 'ARE', 'ARE',
    '3392', '3392', 20, false, true, 'DT One (`3392`) • Product: `30009` (20 AED PIN) • Cost: 2.555 OMR ($6.64 USD) • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Virgin Mobile UAE -> ding (Code: VMAE, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '821f233d-272c-4631-a3d2-e831ddf650c4' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '821f233d-272c-4631-a3d2-e831ddf650c4', 'ding', 'AE', 'AE',
    'VMAE', 'VMAE', 30, false, true, 'DingConnect (`VMAE`) • SKU: `VMAEE2705` (20 AED PIN) • Cost: 2.16 OMR ($5.62 USD) • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Virgin Mobile UAE -> zendit (Code: Virgin Mobile, Priority: 10, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '821f233d-272c-4631-a3d2-e831ddf650c4' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '821f233d-272c-4631-a3d2-e831ddf650c4', 'zendit', 'AE', 'AE',
    'Virgin Mobile', 'Virgin Mobile', 10, false, false, 'Zendit (`Virgin Mobile`) *(Disabled: 0 offers in AE)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Grameenphone -> dtone (Code: 249, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '26dacbcd-1733-4a9c-b468-3589a88597bf' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '26dacbcd-1733-4a9c-b468-3589a88597bf', 'dtone', 'BGD', 'BGD',
    '249', '249', 10, true, true, 'DT One (`249`) • Range: 20–1000 BDT (`11747`) • Cost: 0.078 OMR ($0.203 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Grameenphone -> reloadly (Code: 26, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '26dacbcd-1733-4a9c-b468-3589a88597bf' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '26dacbcd-1733-4a9c-b468-3589a88597bf', 'reloadly', 'BD', 'BD',
    '26', '26', 20, false, true, 'Reloadly (`26` / `834`) • Range: 20–5000 BDT ($0.18 USD) • Cost: $0.18–$44.98 USD • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Grameenphone -> zendit (Code: GrameenPhone, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '26dacbcd-1733-4a9c-b468-3589a88597bf' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '26dacbcd-1733-4a9c-b468-3589a88597bf', 'zendit', 'BD', 'BD',
    'GrameenPhone', 'GrameenPhone', 30, false, true, 'Zendit (`GrameenPhone`) • Offer: `GRAMEENPHONE_BD_OPEN` • Cost: $0.27 USD (21.25 BDT) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Grameenphone -> ding (Code: GEBD, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '26dacbcd-1733-4a9c-b468-3589a88597bf' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '26dacbcd-1733-4a9c-b468-3589a88597bf', 'ding', 'BD', 'BD',
    'GEBD', 'GEBD', 40, false, false, 'DingConnect (`GEBD`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Robi Axiata -> dtone (Code: 1446, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'caafbd48-6451-44d1-9eb0-987af41e7739' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'caafbd48-6451-44d1-9eb0-987af41e7739', 'dtone', 'BGD', 'BGD',
    '1446', '1446', 10, true, true, 'DT One (`1446`) • Range: 20–1000 BDT (`11748`) • Cost: 0.078 OMR ($0.203 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Robi Axiata -> reloadly (Code: 25, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'caafbd48-6451-44d1-9eb0-987af41e7739' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'caafbd48-6451-44d1-9eb0-987af41e7739', 'reloadly', 'BD', 'BD',
    '25', '25', 20, false, true, 'Reloadly (`25` / `835`) • Range: 20–5000 BDT ($0.18 USD) • Cost: $0.18–$44.98 USD • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Robi Axiata -> zendit (Code: Robi, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'caafbd48-6451-44d1-9eb0-987af41e7739' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'caafbd48-6451-44d1-9eb0-987af41e7739', 'zendit', 'BD', 'BD',
    'Robi', 'Robi', 30, false, true, 'Zendit (`Robi`) • Offer: `ROBI_BD_OPEN` • Cost: $0.24 USD (20 BDT) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Robi Axiata -> ding (Code: RLBD, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'caafbd48-6451-44d1-9eb0-987af41e7739' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'caafbd48-6451-44d1-9eb0-987af41e7739', 'ding', 'BD', 'BD',
    'RLBD', 'RLBD', 40, false, false, 'DingConnect (`RLBD`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Banglalink -> dtone (Code: 1447, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b9cbc241-3650-41ab-b8c3-3c9612333dfb' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b9cbc241-3650-41ab-b8c3-3c9612333dfb', 'dtone', 'BGD', 'BGD',
    '1447', '1447', 10, true, true, 'DT One (`1447`) • Range: 20–1000 BDT (`11745`) • Cost: 0.078 OMR ($0.203 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Banglalink -> zendit (Code: Banglalink, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b9cbc241-3650-41ab-b8c3-3c9612333dfb' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b9cbc241-3650-41ab-b8c3-3c9612333dfb', 'zendit', 'BD', 'BD',
    'Banglalink', 'Banglalink', 20, false, true, 'Zendit (`Banglalink`) • Offer: `BANGLALINK_BD_OPEN` • Cost: $0.24 USD (20 BDT) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Banglalink -> reloadly (Code: 24, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b9cbc241-3650-41ab-b8c3-3c9612333dfb' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b9cbc241-3650-41ab-b8c3-3c9612333dfb', 'reloadly', 'BD', 'BD',
    '24', '24', 30, false, true, 'Reloadly (`24` / `28`) • Range: 20–5000 BDT ($0.18 USD) • Cost: $0.18–$44.98 USD • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Banglalink -> ding (Code: BGBD, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b9cbc241-3650-41ab-b8c3-3c9612333dfb' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b9cbc241-3650-41ab-b8c3-3c9612333dfb', 'ding', 'BD', 'BD',
    'BGBD', 'BGBD', 40, false, false, 'DingConnect (`BGBD`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Teletalk Bangladesh -> dtone (Code: 1448, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '4cdb1fd8-65b9-47e6-8626-c63e73878e84' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '4cdb1fd8-65b9-47e6-8626-c63e73878e84', 'dtone', 'BGD', 'BGD',
    '1448', '1448', 10, true, true, 'DT One (`1448`) • Range: 10–1000 BDT (`11749`) • Cost: 0.039 OMR ($0.101 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Teletalk Bangladesh -> reloadly (Code: 27, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '4cdb1fd8-65b9-47e6-8626-c63e73878e84' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '4cdb1fd8-65b9-47e6-8626-c63e73878e84', 'reloadly', 'BD', 'BD',
    '27', '27', 20, false, true, 'Reloadly (`27`) • Range: 20–5000 BDT (2% discount) • Cost: $0.176 USD net • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Teletalk Bangladesh -> zendit (Code: TeleTalk, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '4cdb1fd8-65b9-47e6-8626-c63e73878e84' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '4cdb1fd8-65b9-47e6-8626-c63e73878e84', 'zendit', 'BD', 'BD',
    'TeleTalk', 'TeleTalk', 30, false, true, 'Zendit (`TeleTalk`) • Offer: `TELETALK_BD_OPEN` • Cost: $0.22 USD (20 BDT) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Teletalk Bangladesh -> ding (Code: TQBD, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '4cdb1fd8-65b9-47e6-8626-c63e73878e84' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '4cdb1fd8-65b9-47e6-8626-c63e73878e84', 'ding', 'BD', 'BD',
    'TQBD', 'TQBD', 40, false, false, 'DingConnect (`TQBD`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Airtel Bangladesh -> dtone (Code: 1449, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b0597a41-8a01-477f-85ff-43458caf3243' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b0597a41-8a01-477f-85ff-43458caf3243', 'dtone', 'BGD', 'BGD',
    '1449', '1449', 10, true, true, 'DT One (`1449`) • Range: 20–1000 BDT (`11744`) • Cost: 0.078 OMR ($0.203 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Airtel Bangladesh -> reloadly (Code: 28, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b0597a41-8a01-477f-85ff-43458caf3243' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b0597a41-8a01-477f-85ff-43458caf3243', 'reloadly', 'BD', 'BD',
    '28', '28', 20, false, true, 'Reloadly (`28` / `832`) • Range: 20–5000 BDT ($0.18 USD) • Cost: $0.18–$44.98 USD • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Airtel Bangladesh -> zendit (Code: Airtel, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b0597a41-8a01-477f-85ff-43458caf3243' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b0597a41-8a01-477f-85ff-43458caf3243', 'zendit', 'BD', 'BD',
    'Airtel', 'Airtel', 30, false, true, 'Zendit (`Airtel`) • Offer: `AIRTEL_BD_OPEN` • Cost: $0.26 USD (20 BDT) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Airtel Bangladesh -> ding (Code: AXBD, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b0597a41-8a01-477f-85ff-43458caf3243' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b0597a41-8a01-477f-85ff-43458caf3243', 'ding', 'BD', 'BD',
    'AXBD', 'AXBD', 40, false, false, 'DingConnect (`AXBD`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BH] Batelco -> reloadly (Code: 22, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2cb29ef4-a419-480a-8f5c-c109b5387fbe' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2cb29ef4-a419-480a-8f5c-c109b5387fbe', 'reloadly', 'BH', 'BH',
    '22', '22', 10, true, true, 'Reloadly (`22`) • Operator: `22` • Cost: $2.989 USD (1.15 BHD PIN) • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BH] Batelco -> dtone (Code: 1828, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2cb29ef4-a419-480a-8f5c-c109b5387fbe' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2cb29ef4-a419-480a-8f5c-c109b5387fbe', 'dtone', 'BHR', 'BHR',
    '1828', '1828', 20, false, true, 'DT One (`1828`) • Product: `56728` (2.25 BHD) • Cost: 2.866 OMR ($7.45 USD) • Delivery: 10 Fixed PINs (365d)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BH] Batelco -> ding (Code: BVBH, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2cb29ef4-a419-480a-8f5c-c109b5387fbe' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2cb29ef4-a419-480a-8f5c-c109b5387fbe', 'ding', 'BH', 'BH',
    'BVBH', 'BVBH', 30, false, true, 'DingConnect (`BVBH`) • Provider: `BVBH` • Delivery: Direct / PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BH] Batelco -> zendit (Code: Batelco, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2cb29ef4-a419-480a-8f5c-c109b5387fbe' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2cb29ef4-a419-480a-8f5c-c109b5387fbe', 'zendit', 'BH', 'BH',
    'Batelco', 'Batelco', 40, false, false, 'Zendit (`Batelco`) *(Disabled: 0 catalog offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BH] Zain Bahrain -> reloadly (Code: 1165, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'afee691d-82be-4db4-97da-a6db2f18f8ec' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'afee691d-82be-4db4-97da-a6db2f18f8ec', 'reloadly', 'BH', 'BH',
    '1165', '1165', 10, true, true, 'Reloadly (`1165`) • Operator: `1165` • Cost: $1.55 USD (0.58 BHD) • Delivery: Direct Airtime Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BH] Zain Bahrain -> dtone (Code: 1829, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'afee691d-82be-4db4-97da-a6db2f18f8ec' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'afee691d-82be-4db4-97da-a6db2f18f8ec', 'dtone', 'BHR', 'BHR',
    '1829', '1829', 20, false, true, 'DT One (`1829`) • Product: `58111` (1.00 BHD) • Cost: 1.274 OMR ($3.31 USD) • Delivery: 20 Direct SKUs', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BH] Zain Bahrain -> ding (Code: ZABH, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'afee691d-82be-4db4-97da-a6db2f18f8ec' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'afee691d-82be-4db4-97da-a6db2f18f8ec', 'ding', 'BH', 'BH',
    'ZABH', 'ZABH', 30, false, true, 'DingConnect (`ZABH`) • Provider: `ZABH` • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BH] Zain Bahrain -> zendit (Code: Zain, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'afee691d-82be-4db4-97da-a6db2f18f8ec' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'afee691d-82be-4db4-97da-a6db2f18f8ec', 'zendit', 'BH', 'BH',
    'Zain', 'Zain', 40, false, false, 'Zendit (`Zain`) *(Disabled: 0 catalog offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BH] STC Bahrain -> ding (Code: STC, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3566da00-6c46-48f3-aafb-c8370bc5e12c' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3566da00-6c46-48f3-aafb-c8370bc5e12c', 'ding', 'BH', 'BH',
    'STC', 'STC', 10, true, true, 'DingConnect (`STC`) • Gateway: Local / API', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BH] STC Bahrain -> reloadly (Code: STC, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3566da00-6c46-48f3-aafb-c8370bc5e12c' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3566da00-6c46-48f3-aafb-c8370bc5e12c', 'reloadly', 'BH', 'BH',
    'STC', 'STC', 20, false, false, '🔴 Disabled (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BH] STC Bahrain -> dtone (Code: STC, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3566da00-6c46-48f3-aafb-c8370bc5e12c' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3566da00-6c46-48f3-aafb-c8370bc5e12c', 'dtone', 'BHR', 'BHR',
    'STC', 'STC', 30, false, false, '🔴 Disabled (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BH] STC Bahrain -> zendit (Code: STC, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3566da00-6c46-48f3-aafb-c8370bc5e12c' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3566da00-6c46-48f3-aafb-c8370bc5e12c', 'zendit', 'BH', 'BH',
    'STC', 'STC', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Deutsche Telekom -> dtone (Code: 602, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f3bd840a-bc97-4ae2-8206-e27f0cf94e56' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f3bd840a-bc97-4ae2-8206-e27f0cf94e56', 'dtone', 'DEU', 'DEU',
    '602', '602', 10, true, true, 'DT One (`602`) • Denom: 5 EUR PIN / 10 EUR Direct • Cost: 2.781 OMR / 5.382 OMR • Delivery: Direct Top-Up & PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Deutsche Telekom -> reloadly (Code: 664, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f3bd840a-bc97-4ae2-8206-e27f0cf94e56' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f3bd840a-bc97-4ae2-8206-e27f0cf94e56', 'reloadly', 'DE', 'DE',
    '664', '664', 20, false, true, 'Reloadly (`664` / `873`) • Denom: 15 EUR PIN ($17.65 USD) • Cost: $17.65 USD • Delivery: Digital PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Deutsche Telekom -> zendit (Code: Telekom, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f3bd840a-bc97-4ae2-8206-e27f0cf94e56' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f3bd840a-bc97-4ae2-8206-e27f0cf94e56', 'zendit', 'DE', 'DE',
    'Telekom', 'Telekom', 30, false, true, 'Zendit (`Telekom`) • Offer: `TELEKOM_DE_001-ROW` • Cost: $16.84 USD (15 EUR) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Deutsche Telekom -> ding (Code: TLDE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f3bd840a-bc97-4ae2-8206-e27f0cf94e56' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f3bd840a-bc97-4ae2-8206-e27f0cf94e56', 'ding', 'DE', 'DE',
    'TLDE', 'TLDE', 40, false, false, 'DingConnect (`TLDE` / `M4DE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Vodafone Germany -> dtone (Code: 718, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '34abfdf0-66c9-42f1-94eb-59e5219e6d8d' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '34abfdf0-66c9-42f1-94eb-59e5219e6d8d', 'dtone', 'DEU', 'DEU',
    '718', '718', 10, true, true, 'DT One (`718`) • Denom: 15 EUR (`15313` / `23386`) • Cost: 8.084 OMR / 8.047 OMR • Delivery: Direct Top-Up & PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Vodafone Germany -> reloadly (Code: 875, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '34abfdf0-66c9-42f1-94eb-59e5219e6d8d' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '34abfdf0-66c9-42f1-94eb-59e5219e6d8d', 'reloadly', 'DE', 'DE',
    '875', '875', 20, false, true, 'Reloadly (`875`) • Denom: 15 EUR PIN ($17.86 USD) • Cost: $17.86 USD • Delivery: Digital PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Vodafone Germany -> zendit (Code: Vodafone, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '34abfdf0-66c9-42f1-94eb-59e5219e6d8d' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '34abfdf0-66c9-42f1-94eb-59e5219e6d8d', 'zendit', 'DE', 'DE',
    'Vodafone', 'Vodafone', 30, false, true, 'Zendit (`Vodafone`) • Offer: `VODAFONE_DE_001-ROW` • Cost: $18.59 USD (15 EUR) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Vodafone Germany -> ding (Code: VFDE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '34abfdf0-66c9-42f1-94eb-59e5219e6d8d' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '34abfdf0-66c9-42f1-94eb-59e5219e6d8d', 'ding', 'DE', 'DE',
    'VFDE', 'VFDE', 40, false, false, 'DingConnect (`VFDE` / `V6DE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] O2 Germany -> dtone (Code: 451, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8e147f7a-60b7-45cc-8c32-5b7359007596' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8e147f7a-60b7-45cc-8c32-5b7359007596', 'dtone', 'DEU', 'DEU',
    '451', '451', 10, true, true, 'DT One (`451`) • Denom: 15 EUR (`15301` / `23408`) • Cost: 8.149 OMR / 8.047 OMR • Delivery: Direct Top-Up & PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] O2 Germany -> reloadly (Code: 868, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8e147f7a-60b7-45cc-8c32-5b7359007596' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8e147f7a-60b7-45cc-8c32-5b7359007596', 'reloadly', 'DE', 'DE',
    '868', '868', 20, false, true, 'Reloadly (`868`) • Denom: 15 EUR PIN ($17.86 USD) • Cost: $17.86 USD • Delivery: Digital PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] O2 Germany -> zendit (Code: O2, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8e147f7a-60b7-45cc-8c32-5b7359007596' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8e147f7a-60b7-45cc-8c32-5b7359007596', 'zendit', 'DE', 'DE',
    'O2', 'O2', 30, false, true, 'Zendit (`O2`) • Offer: `O2_DE_001-ROW` • Cost: $18.75 USD (15 EUR) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] O2 Germany -> ding (Code: O2DE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8e147f7a-60b7-45cc-8c32-5b7359007596' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8e147f7a-60b7-45cc-8c32-5b7359007596', 'ding', 'DE', 'DE',
    'O2DE', 'O2DE', 40, false, false, 'DingConnect (`O2DE` / `O1DE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Congstar -> reloadly (Code: 850, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7f12a660-ab11-47a2-bf13-6cd7a86bb51b' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7f12a660-ab11-47a2-bf13-6cd7a86bb51b', 'reloadly', 'DE', 'DE',
    '850', '850', 10, true, true, 'Reloadly (`850`) • Denom: 5 EUR PIN ($5.95 USD) • Cost: $5.8905 USD net • Delivery: Digital PIN (Micro-Refill)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Congstar -> zendit (Code: Congstar, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7f12a660-ab11-47a2-bf13-6cd7a86bb51b' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7f12a660-ab11-47a2-bf13-6cd7a86bb51b', 'zendit', 'DE', 'DE',
    'Congstar', 'Congstar', 20, false, true, 'Zendit (`Congstar`) • Offer: `CONGSTAR_DE_001-ROW` • Cost: $18.52 USD (15 EUR) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Congstar -> dtone (Code: 2139, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7f12a660-ab11-47a2-bf13-6cd7a86bb51b' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7f12a660-ab11-47a2-bf13-6cd7a86bb51b', 'dtone', 'DEU', 'DEU',
    '2139', '2139', 30, false, false, 'DT One (`2139`) *(Disabled: 0 pre-prod SKUs)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Congstar -> ding (Code: C4DE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7f12a660-ab11-47a2-bf13-6cd7a86bb51b' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7f12a660-ab11-47a2-bf13-6cd7a86bb51b', 'ding', 'DE', 'DE',
    'C4DE', 'C4DE', 40, false, false, 'DingConnect (`C4DE` / `C7DE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Lebara Germany -> reloadly (Code: 855, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8babd7c3-3cff-41a2-87c7-44e193831f78' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8babd7c3-3cff-41a2-87c7-44e193831f78', 'reloadly', 'DE', 'DE',
    '855', '855', 10, true, true, 'Reloadly (`855` / `857`) • Denom: 9.99 EUR Bundle / 10 EUR PIN • Cost: $11.53 USD net / $11.90 USD • Delivery: Direct Bundle & PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Lebara Germany -> dtone (Code: 2728, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8babd7c3-3cff-41a2-87c7-44e193831f78' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8babd7c3-3cff-41a2-87c7-44e193831f78', 'dtone', 'DEU', 'DEU',
    '2728', '2728', 20, false, false, 'DT One (`2728` / `6016`) *(Disabled: 0 pre-prod SKUs)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Lebara Germany -> zendit (Code: Lebara, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8babd7c3-3cff-41a2-87c7-44e193831f78' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8babd7c3-3cff-41a2-87c7-44e193831f78', 'zendit', 'DE', 'DE',
    'Lebara', 'Lebara', 40, false, false, '🔴 Disabled (`is_enabled: false`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Lebara Germany -> ding (Code: ESDE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8babd7c3-3cff-41a2-87c7-44e193831f78' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8babd7c3-3cff-41a2-87c7-44e193831f78', 'ding', 'DE', 'DE',
    'ESDE', 'ESDE', 40, false, false, 'DingConnect (`ESDE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Lycamobile Germany -> reloadly (Code: 864, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3253ab0d-a79a-4e19-ac72-458c6a41b519' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3253ab0d-a79a-4e19-ac72-458c6a41b519', 'reloadly', 'DE', 'DE',
    '864', '864', 10, true, true, 'Reloadly (`864` / `865`) • Denom: 5 EUR PIN ($5.92 USD) • Cost: $5.92 USD (Starting 5 EUR) • Delivery: Digital PIN (Micro-Refill)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Lycamobile Germany -> dtone (Code: 2121, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3253ab0d-a79a-4e19-ac72-458c6a41b519' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3253ab0d-a79a-4e19-ac72-458c6a41b519', 'dtone', 'DEU', 'DEU',
    '2121', '2121', 20, false, false, 'DT One (`2121`) *(Disabled: 0 pre-prod SKUs)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Lycamobile Germany -> zendit (Code: Lycamobile, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3253ab0d-a79a-4e19-ac72-458c6a41b519' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3253ab0d-a79a-4e19-ac72-458c6a41b519', 'zendit', 'DE', 'DE',
    'Lycamobile', 'Lycamobile', 40, false, false, '🔴 Disabled (`is_enabled: false`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Lycamobile Germany -> ding (Code: LYDE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3253ab0d-a79a-4e19-ac72-458c6a41b519' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3253ab0d-a79a-4e19-ac72-458c6a41b519', 'ding', 'DE', 'DE',
    'LYDE', 'LYDE', 40, false, false, 'DingConnect (`LYDE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Blau -> reloadly (Code: 849, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7b5c7719-b34b-4c51-a2c6-b486c6b90e67' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7b5c7719-b34b-4c51-a2c6-b486c6b90e67', 'reloadly', 'DE', 'DE',
    '849', '849', 10, true, true, 'Reloadly (`849`) • Denom: 15 EUR PIN ($17.86 USD) • Cost: $17.5028 USD net • Delivery: Digital PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Blau -> zendit (Code: Blau, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7b5c7719-b34b-4c51-a2c6-b486c6b90e67' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7b5c7719-b34b-4c51-a2c6-b486c6b90e67', 'zendit', 'DE', 'DE',
    'Blau', 'Blau', 20, false, true, 'Zendit (`Blau`) • Offer: `BLAU_DE_001-ROW` • Cost: $18.99 USD (15 EUR) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Blau -> dtone (Code: 2754, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7b5c7719-b34b-4c51-a2c6-b486c6b90e67' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7b5c7719-b34b-4c51-a2c6-b486c6b90e67', 'dtone', 'DEU', 'DEU',
    '2754', '2754', 30, false, false, 'DT One (`2754`) *(Disabled: 0 pre-prod SKUs)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Blau -> ding (Code: BSDE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7b5c7719-b34b-4c51-a2c6-b486c6b90e67' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7b5c7719-b34b-4c51-a2c6-b486c6b90e67', 'ding', 'DE', 'DE',
    'BSDE', 'BSDE', 40, false, false, 'DingConnect (`BSDE` / `B7DE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ortel Mobile -> reloadly (Code: 665, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2652fd9d-22d8-4935-8aab-c84bcfe38026' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2652fd9d-22d8-4935-8aab-c84bcfe38026', 'reloadly', 'DE', 'DE',
    '665', '665', 10, true, true, 'Reloadly (`665`) • Denom: 15 EUR PIN ($17.86 USD) • Cost: $17.6814 USD net • Delivery: Digital PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ortel Mobile -> zendit (Code: Ortel, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2652fd9d-22d8-4935-8aab-c84bcfe38026' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2652fd9d-22d8-4935-8aab-c84bcfe38026', 'zendit', 'DE', 'DE',
    'Ortel', 'Ortel', 20, false, true, 'Zendit (`Ortel`) • Offer: `ORTEL_DE_001-ROW` • Cost: $18.75 USD (15 EUR) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ortel Mobile -> dtone (Code: 2146, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2652fd9d-22d8-4935-8aab-c84bcfe38026' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2652fd9d-22d8-4935-8aab-c84bcfe38026', 'dtone', 'DEU', 'DEU',
    '2146', '2146', 30, false, false, 'DT One (`2146`) *(Disabled: 0 pre-prod SKUs)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ortel Mobile -> ding (Code: OTDE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2652fd9d-22d8-4935-8aab-c84bcfe38026' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2652fd9d-22d8-4935-8aab-c84bcfe38026', 'ding', 'DE', 'DE',
    'OTDE', 'OTDE', 40, false, false, 'DingConnect (`OTDE` / `O3DE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ay Yildiz -> zendit (Code: AyYildiz, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '51547096-c721-4d93-8bfc-489780c5fe4a' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '51547096-c721-4d93-8bfc-489780c5fe4a', 'zendit', 'DE', 'DE',
    'AyYildiz', 'AyYildiz', 10, true, true, 'Zendit (`AyYildiz`) • Offer: `AYYILDIZ_DE_001-ROW` • Cost: $18.73 USD (15 EUR) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ay Yildiz -> dtone (Code: 2135, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '51547096-c721-4d93-8bfc-489780c5fe4a' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '51547096-c721-4d93-8bfc-489780c5fe4a', 'dtone', 'DEU', 'DEU',
    '2135', '2135', 20, false, false, 'DT One (`2135`) *(Disabled: 0 pre-prod SKUs)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ay Yildiz -> ding (Code: AYDE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '51547096-c721-4d93-8bfc-489780c5fe4a' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '51547096-c721-4d93-8bfc-489780c5fe4a', 'ding', 'DE', 'DE',
    'AYDE', 'AYDE', 40, false, false, 'DingConnect (`AYDE` / `A9DE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Otelo -> reloadly (Code: 867, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '94231364-38c7-4bdf-9327-0d95c4a7a1af' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '94231364-38c7-4bdf-9327-0d95c4a7a1af', 'reloadly', 'DE', 'DE',
    '867', '867', 10, true, true, 'Reloadly (`867`) • Denom: 9 EUR PIN ($9.00 USD) • Cost: $9.00 USD (Entry 9 EUR) • Delivery: Digital PIN (Micro-Refill)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Otelo -> zendit (Code: OTELO, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '94231364-38c7-4bdf-9327-0d95c4a7a1af' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '94231364-38c7-4bdf-9327-0d95c4a7a1af', 'zendit', 'DE', 'DE',
    'OTELO', 'OTELO', 20, false, true, 'Zendit (`OTELO`) • Offer: `OTELO_DE_001-ROW` • Cost: $11.25 USD (9 EUR) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Otelo -> dtone (Code: 2148, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '94231364-38c7-4bdf-9327-0d95c4a7a1af' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '94231364-38c7-4bdf-9327-0d95c4a7a1af', 'dtone', 'DEU', 'DEU',
    '2148', '2148', 30, false, false, 'DT One (`2148`) *(Disabled: 0 pre-prod SKUs)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Otelo -> ding (Code: OEDE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '94231364-38c7-4bdf-9327-0d95c4a7a1af' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '94231364-38c7-4bdf-9327-0d95c4a7a1af', 'ding', 'DE', 'DE',
    'OEDE', 'OEDE', 40, false, false, 'DingConnect (`OEDE` / `O4DE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Fonic -> reloadly (Code: 853, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '70754905-9221-4142-a400-b68f51bdd78e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '70754905-9221-4142-a400-b68f51bdd78e', 'reloadly', 'DE', 'DE',
    '853', '853', 10, true, true, 'Reloadly (`853`) • Denom: 20 EUR PIN ($23.81 USD) • Cost: $23.81 USD • Delivery: Digital PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Fonic -> dtone (Code: 2768, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '70754905-9221-4142-a400-b68f51bdd78e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '70754905-9221-4142-a400-b68f51bdd78e', 'dtone', 'DEU', 'DEU',
    '2768', '2768', 20, false, false, 'DT One (`2768`) *(Disabled: 0 pre-prod SKUs)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Fonic -> ding (Code: F1DE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '70754905-9221-4142-a400-b68f51bdd78e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '70754905-9221-4142-a400-b68f51bdd78e', 'ding', 'DE', 'DE',
    'F1DE', 'F1DE', 40, false, false, 'DingConnect (`F1DE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Tchibo Mobil -> reloadly (Code: 872, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'cc280785-dcd2-4f7c-9855-c8eba807808e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'cc280785-dcd2-4f7c-9855-c8eba807808e', 'reloadly', 'DE', 'DE',
    '872', '872', 10, true, true, 'Reloadly (`872`) • Denom: 20 EUR PIN ($23.81 USD) • Cost: $23.81 USD • Delivery: Digital PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Tchibo Mobil -> ding (Code: E825B8DE, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'cc280785-dcd2-4f7c-9855-c8eba807808e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'cc280785-dcd2-4f7c-9855-c8eba807808e', 'ding', 'DE', 'DE',
    'E825B8DE', 'E825B8DE', 20, false, false, 'DingConnect (`E825B8DE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Klarmobil -> reloadly (Code: 854, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '88e44ab2-2e75-4159-8695-e35937f70b7d' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '88e44ab2-2e75-4159-8695-e35937f70b7d', 'reloadly', 'DE', 'DE',
    '854', '854', 10, true, true, 'Reloadly (`854`) • Denom: 15 EUR PIN ($17.86 USD) • Cost: $17.86 USD • Delivery: Digital PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Klarmobil -> dtone (Code: 3117, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '88e44ab2-2e75-4159-8695-e35937f70b7d' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '88e44ab2-2e75-4159-8695-e35937f70b7d', 'dtone', 'DEU', 'DEU',
    '3117', '3117', 20, false, false, 'DT One (`3117`) *(Disabled: 0 pre-prod SKUs)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] BILDmobil -> reloadly (Code: 848, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '55100b54-dc63-4838-bba0-44fea2bae915' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '55100b54-dc63-4838-bba0-44fea2bae915', 'reloadly', 'DE', 'DE',
    '848', '848', 10, true, true, 'Reloadly (`848`) • Denom: 10 EUR PIN ($11.90 USD) • Cost: $11.781 USD net • Delivery: Digital PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] BILDmobil -> dtone (Code: 3111, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '55100b54-dc63-4838-bba0-44fea2bae915' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '55100b54-dc63-4838-bba0-44fea2bae915', 'dtone', 'DEU', 'DEU',
    '3111', '3111', 20, false, false, 'DT One (`3111`) *(Disabled: 0 pre-prod SKUs)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] BILDmobil -> ding (Code: B6DE, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '55100b54-dc63-4838-bba0-44fea2bae915' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '55100b54-dc63-4838-bba0-44fea2bae915', 'ding', 'DE', 'DE',
    'B6DE', 'B6DE', 30, false, false, 'DingConnect (`B6DE`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DZ] Mobilis -> zendit (Code: MOBILIS, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '882272bc-6600-40ab-be8e-1cac32b777b2' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '882272bc-6600-40ab-be8e-1cac32b777b2', 'zendit', 'DZ', 'DZ',
    'MOBILIS', 'MOBILIS', 10, true, true, 'Zendit (`MOBILIS`) • Fixed: 100–2000 DZD (`MOBILIS_DZ_01`+) • Cost: $0.71 USD (100 DZD) • Delivery: Direct Airtime Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DZ] Mobilis -> dtone (Code: 4, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '882272bc-6600-40ab-be8e-1cac32b777b2' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '882272bc-6600-40ab-be8e-1cac32b777b2', 'dtone', 'DZA', 'DZA',
    '4', '4', 20, false, true, 'DT One (`4`) • Fixed: 100–2000 DZD (`14299`+) • Cost: 0.296 OMR ($0.770 USD) • Delivery: Direct Airtime Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DZ] Mobilis -> reloadly (Code: 6, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '882272bc-6600-40ab-be8e-1cac32b777b2' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '882272bc-6600-40ab-be8e-1cac32b777b2', 'reloadly', 'DZ', 'DZ',
    '6', '6', 30, false, true, 'Reloadly (`6`) • Fixed: 100–2000 DZD ($0.97 USD) • Cost: $0.9215–$18.40 USD net • Delivery: Direct Airtime Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DZ] Mobilis -> ding (Code: MDDZ, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '882272bc-6600-40ab-be8e-1cac32b777b2' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '882272bc-6600-40ab-be8e-1cac32b777b2', 'ding', 'DZ', 'DZ',
    'MDDZ', 'MDDZ', 40, false, false, 'DingConnect (`MDDZ`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DZ] Djezzy -> zendit (Code: DJEZZY, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b25621ff-7000-4fbe-9e41-eb6888f17554' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b25621ff-7000-4fbe-9e41-eb6888f17554', 'zendit', 'DZ', 'DZ',
    'DJEZZY', 'DJEZZY', 10, true, true, 'Zendit (`DJEZZY`) • Fixed: 100–2000 DZD (`DJEZZY_DZ_01`+) • Cost: $0.71 USD (100 DZD) • Delivery: Direct Airtime Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DZ] Djezzy -> dtone (Code: 2074, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b25621ff-7000-4fbe-9e41-eb6888f17554' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b25621ff-7000-4fbe-9e41-eb6888f17554', 'dtone', 'DZA', 'DZA',
    '2074', '2074', 20, false, true, 'DT One (`2074`) • Fixed: 100–2000 DZD (`14308`+) • Cost: 0.296 OMR ($0.770 USD) • Delivery: Direct Airtime Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DZ] Djezzy -> reloadly (Code: 8, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b25621ff-7000-4fbe-9e41-eb6888f17554' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b25621ff-7000-4fbe-9e41-eb6888f17554', 'reloadly', 'DZ', 'DZ',
    '8', '8', 30, false, true, 'Reloadly (`8`) • Fixed: 500–2000 DZD ($4.84 USD) • Cost: $4.598–$18.40 USD net • Delivery: Direct Airtime Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DZ] Djezzy -> ding (Code: DJDZ, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b25621ff-7000-4fbe-9e41-eb6888f17554' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b25621ff-7000-4fbe-9e41-eb6888f17554', 'ding', 'DZ', 'DZ',
    'DJDZ', 'DJDZ', 40, false, false, 'DingConnect (`DJDZ`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DZ] Ooredoo Algeria -> zendit (Code: OOREDOO, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ef94a579-d459-411e-b806-cbd2bf8d5db6' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ef94a579-d459-411e-b806-cbd2bf8d5db6', 'zendit', 'DZ', 'DZ',
    'OOREDOO', 'OOREDOO', 10, true, true, 'Zendit (`OOREDOO`) • Fixed: 100–2000 DZD (`OOREDOO_DZ_01`+) • Cost: $0.73 USD (100 DZD) • Delivery: Direct Airtime Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DZ] Ooredoo Algeria -> dtone (Code: 2075, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ef94a579-d459-411e-b806-cbd2bf8d5db6' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ef94a579-d459-411e-b806-cbd2bf8d5db6', 'dtone', 'DZA', 'DZA',
    '2075', '2075', 20, false, true, 'DT One (`2075`) • Fixed: 100–2000 DZD (`14317`+) • Cost: 0.296 OMR ($0.770 USD) • Delivery: Direct Airtime & MAXY/Data Bundles', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DZ] Ooredoo Algeria -> reloadly (Code: 7, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ef94a579-d459-411e-b806-cbd2bf8d5db6' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ef94a579-d459-411e-b806-cbd2bf8d5db6', 'reloadly', 'DZ', 'DZ',
    '7', '7', 30, false, true, 'Reloadly (`7`) • Fixed: 100–2000 DZD ($0.97 USD) • Cost: $0.9215–$18.40 USD net • Delivery: Direct Airtime Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DZ] Ooredoo Algeria -> ding (Code: OODZ, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ef94a579-d459-411e-b806-cbd2bf8d5db6' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ef94a579-d459-411e-b806-cbd2bf8d5db6', 'ding', 'DZ', 'DZ',
    'OODZ', 'OODZ', 40, false, false, 'DingConnect (`OODZ`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] Vodafone Egypt -> reloadly (Code: 119, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '08ccb7e2-52a0-4002-ad88-672a517cba4f' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '08ccb7e2-52a0-4002-ad88-672a517cba4f', 'reloadly', 'EG', 'EG',
    '119', '119', 10, true, true, 'Reloadly (`119`) • Amount: $0.25 USD ($0.238 net) • Yield: ~8.82 EGP • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] Vodafone Egypt -> zendit (Code: Vodafone, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '08ccb7e2-52a0-4002-ad88-672a517cba4f' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '08ccb7e2-52a0-4002-ad88-672a517cba4f', 'zendit', 'EG', 'EG',
    'Vodafone', 'Vodafone', 20, false, true, 'Zendit (`Vodafone`) • Offer: `VODAFONE_EG_OPEN` • Cost: $0.25 USD ($0.20 net) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] Vodafone Egypt -> dtone (Code: 716, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '08ccb7e2-52a0-4002-ad88-672a517cba4f' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '08ccb7e2-52a0-4002-ad88-672a517cba4f', 'dtone', 'EGY', 'EGY',
    '716', '716', 30, false, true, 'DT One (`716`) • Product: `3912` (10 EGP) • Cost: 0.095 OMR ($0.25 USD) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] Vodafone Egypt -> ding (Code: VFEG, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '08ccb7e2-52a0-4002-ad88-672a517cba4f' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '08ccb7e2-52a0-4002-ad88-672a517cba4f', 'ding', 'EG', 'EG',
    'VFEG', 'VFEG', 40, false, false, 'DingConnect (`VFEG`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] Orange Egypt -> dtone (Code: 190, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '72d2fd98-a319-493f-8ee0-2c079530a9ac' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '72d2fd98-a319-493f-8ee0-2c079530a9ac', 'dtone', 'EGY', 'EGY',
    '190', '190', 10, true, true, 'DT One (`190`) • Product: `3913` (10 EGP) • Cost: 0.092 OMR ($0.24 USD) • Delivery: Direct Airtime (Micro)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] Orange Egypt -> reloadly (Code: 118, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '72d2fd98-a319-493f-8ee0-2c079530a9ac' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '72d2fd98-a319-493f-8ee0-2c079530a9ac', 'reloadly', 'EG', 'EG',
    '118', '118', 20, false, true, 'Reloadly (`118`) • Range: $3.95 USD ($3.83 net) • Yield: ~170 EGP • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] Orange Egypt -> zendit (Code: Orange, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '72d2fd98-a319-493f-8ee0-2c079530a9ac' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '72d2fd98-a319-493f-8ee0-2c079530a9ac', 'zendit', 'EG', 'EG',
    'Orange', 'Orange', 30, false, true, 'Zendit (`Orange`) • Offer: `ORANGE_EG_OPEN` • Cost: $3.95 USD ($3.67 net) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] Orange Egypt -> ding (Code: OREG, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '72d2fd98-a319-493f-8ee0-2c079530a9ac' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '72d2fd98-a319-493f-8ee0-2c079530a9ac', 'ding', 'EG', 'EG',
    'OREG', 'OREG', 40, false, false, 'DingConnect (`OREG`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] Etisalat Egypt -> reloadly (Code: 120, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3c51f2ca-1e38-44d1-b777-4b08e9316e5c' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3c51f2ca-1e38-44d1-b777-4b08e9316e5c', 'reloadly', 'EG', 'EG',
    '120', '120', 10, true, true, 'Reloadly (`120`) • SKU: `rl_120_0.17` (5.10 EGP) • Cost: $0.17 USD ($0.162 net) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] Etisalat Egypt -> zendit (Code: Etisalat, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3c51f2ca-1e38-44d1-b777-4b08e9316e5c' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3c51f2ca-1e38-44d1-b777-4b08e9316e5c', 'zendit', 'EG', 'EG',
    'Etisalat', 'Etisalat', 20, false, true, 'Zendit (`Etisalat`) • Offer: `ETISALAT_EG_001` (5 EGP) • Cost: $0.25 USD ($0.13 net) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] Etisalat Egypt -> dtone (Code: 1451, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3c51f2ca-1e38-44d1-b777-4b08e9316e5c' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3c51f2ca-1e38-44d1-b777-4b08e9316e5c', 'dtone', 'EGY', 'EGY',
    '1451', '1451', 30, false, true, 'DT One (`1451`) • Product: `3570` (10 EGP) • Cost: 0.090 OMR ($0.23 USD) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] Etisalat Egypt -> ding (Code: ETEG, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3c51f2ca-1e38-44d1-b777-4b08e9316e5c' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3c51f2ca-1e38-44d1-b777-4b08e9316e5c', 'ding', 'EG', 'EG',
    'ETEG', 'ETEG', 40, false, false, 'DingConnect (`ETEG`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] WE (Telecom Egypt) -> zendit (Code: WETelecom, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e196d805-eecc-4c46-a937-df3140688f6e' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e196d805-eecc-4c46-a937-df3140688f6e', 'zendit', 'EG', 'EG',
    'WETelecom', 'WETelecom', 10, true, true, 'Zendit (`WETelecom`) • Offer: `WETELECOM_EG_01` (100 EGP) • Cost: $2.63 USD ($2.33 net) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] WE (Telecom Egypt) -> dtone (Code: 2982, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e196d805-eecc-4c46-a937-df3140688f6e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e196d805-eecc-4c46-a937-df3140688f6e', 'dtone', 'EGY', 'EGY',
    '2982', '2982', 20, false, true, 'DT One (`2982`) • Product: `66945` (100 EGP) • Cost: 0.995 OMR ($2.59 USD) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] WE (Telecom Egypt) -> reloadly (Code: 1216, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e196d805-eecc-4c46-a937-df3140688f6e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e196d805-eecc-4c46-a937-df3140688f6e', 'reloadly', 'EG', 'EG',
    '1216', '1216', 30, false, true, 'Reloadly (`1216`) • Range: $2.93 USD ($2.78 net) • Yield: ~88 EGP • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [EG] WE (Telecom Egypt) -> ding (Code: 39EG, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e196d805-eecc-4c46-a937-df3140688f6e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e196d805-eecc-4c46-a937-df3140688f6e', 'ding', 'EG', 'EG',
    '39EG', '39EG', 40, false, false, 'DingConnect (`39EG`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Jio -> dtone (Code: 2808, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e', 'dtone', 'IND', 'IND',
    '2808', '2808', 10, true, true, 'DT One (`2808`) • Product: `18922` (349 INR 28d) • Cost: 1.648 OMR ($4.28 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Jio -> zendit (Code: Jio, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e', 'zendit', 'IN', 'IN',
    'Jio', 'Jio', 20, false, true, 'Zendit (`Jio`) • Offer: `JIO_IN_3-I-BUNDLE` • Cost: $3.08 USD (239 INR) • Delivery: Direct Bundle', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Jio -> reloadly (Code: 786, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e', 'reloadly', 'IN', 'IN',
    '786', '786', 30, false, true, 'Reloadly (`786`) • Operator: `786` • Cost: Catalog Mapped • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Jio -> ding (Code: RJIN, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e', 'ding', 'IN', 'IN',
    'RJIN', 'RJIN', 40, false, false, 'DingConnect (`RJIN`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Airtel -> dtone (Code: 1371, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd34d491a-cbc8-4a31-901b-0b2279bb73c0' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd34d491a-cbc8-4a31-901b-0b2279bb73c0', 'dtone', 'IND', 'IND',
    '1371', '1371', 10, true, true, 'DT One (`1371`) • Product: `8141` (10 INR TT) • Cost: 0.048 OMR ($0.12 USD) • Delivery: Direct Micro-Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Airtel -> zendit (Code: Airtel, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd34d491a-cbc8-4a31-901b-0b2279bb73c0' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd34d491a-cbc8-4a31-901b-0b2279bb73c0', 'zendit', 'IN', 'IN',
    'Airtel', 'Airtel', 20, false, true, 'Zendit (`Airtel`) • Offer: `AIRTEL_IN_4.5-I-BUNDLE` • Cost: $4.51 USD (349 INR) • Delivery: Direct Bundle', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Airtel -> reloadly (Code: 200, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd34d491a-cbc8-4a31-901b-0b2279bb73c0' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd34d491a-cbc8-4a31-901b-0b2279bb73c0', 'reloadly', 'IN', 'IN',
    '200', '200', 30, false, true, 'Reloadly (`200`) • Operator: `200` • Cost: Catalog Mapped • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Airtel -> ding (Code: AIIN, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd34d491a-cbc8-4a31-901b-0b2279bb73c0' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd34d491a-cbc8-4a31-901b-0b2279bb73c0', 'ding', 'IN', 'IN',
    'AIIN', 'AIIN', 40, false, false, 'DingConnect (`AIIN`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Vi (Vodafone Idea) -> dtone (Code: 2016, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '0114b343-003e-4a2a-a4ae-8daabe73e5dd' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '0114b343-003e-4a2a-a4ae-8daabe73e5dd', 'dtone', 'IND', 'IND',
    '2016', '2016', 10, true, true, 'DT One (`2016`) • Product: `28303` (10 INR TT) • Cost: 0.048 OMR ($0.12 USD) • Delivery: Direct Micro-Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Vi (Vodafone Idea) -> zendit (Code: VodafoneIdea, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '0114b343-003e-4a2a-a4ae-8daabe73e5dd' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '0114b343-003e-4a2a-a4ae-8daabe73e5dd', 'zendit', 'IN', 'IN',
    'VodafoneIdea', 'VodafoneIdea', 20, false, true, 'Zendit (`VodafoneIdea`) • Offer: `VODAFONEIDEA_IN_4.5-I-BUNDLE` • Cost: $3.86 USD (299 INR) • Delivery: Direct Bundle', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Vi (Vodafone Idea) -> reloadly (Code: 716, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '0114b343-003e-4a2a-a4ae-8daabe73e5dd' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '0114b343-003e-4a2a-a4ae-8daabe73e5dd', 'reloadly', 'IN', 'IN',
    '716', '716', 30, false, true, 'Reloadly (`716`) • Operator: `716` • Cost: Catalog Mapped • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Vi (Vodafone Idea) -> ding (Code: VFIN, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '0114b343-003e-4a2a-a4ae-8daabe73e5dd' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '0114b343-003e-4a2a-a4ae-8daabe73e5dd', 'ding', 'IN', 'IN',
    'VFIN', 'VFIN', 40, false, false, 'DingConnect (`VFIN`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] BSNL -> dtone (Code: 1420, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1e07e23c-b088-4ded-9a3c-fc41d3e46f97' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1e07e23c-b088-4ded-9a3c-fc41d3e46f97', 'dtone', 'IND', 'IND',
    '1420', '1420', 10, true, true, 'DT One (`1420`) • Product: `11087` (10 INR TT) • Cost: 0.048 OMR ($0.12 USD) • Delivery: Direct Micro-Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] BSNL -> zendit (Code: BSNL, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1e07e23c-b088-4ded-9a3c-fc41d3e46f97' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1e07e23c-b088-4ded-9a3c-fc41d3e46f97', 'zendit', 'IN', 'IN',
    'BSNL', 'BSNL', 20, false, true, 'Zendit (`BSNL`) • Offer: `BSNL_IN_2.7-I-BUNDLE` • Cost: $2.57 USD (199 INR) • Delivery: Direct Bundle', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] BSNL -> reloadly (Code: 193, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1e07e23c-b088-4ded-9a3c-fc41d3e46f97' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1e07e23c-b088-4ded-9a3c-fc41d3e46f97', 'reloadly', 'IN', 'IN',
    '193', '193', 30, false, true, 'Reloadly (`193`) • Operator: `193` • Cost: Catalog Mapped • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] BSNL -> ding (Code: BLIN, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1e07e23c-b088-4ded-9a3c-fc41d3e46f97' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1e07e23c-b088-4ded-9a3c-fc41d3e46f97', 'ding', 'IN', 'IN',
    'BLIN', 'BLIN', 40, false, false, 'DingConnect (`BLIN`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] MTNL (Delhi / Mumbai) -> dtone (Code: 368, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ba06511f-05c6-4922-9ae9-3536b71bba27' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ba06511f-05c6-4922-9ae9-3536b71bba27', 'dtone', 'IND', 'IND',
    '368', '368', 10, true, true, 'DT One (`368`) • Product: `13500` (10 INR TT) • Cost: 0.048 OMR ($0.12 USD) • Delivery: Exclusive Direct Route', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] MTNL (Delhi / Mumbai) -> zendit (Code: MTNL, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ba06511f-05c6-4922-9ae9-3536b71bba27' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ba06511f-05c6-4922-9ae9-3536b71bba27', 'zendit', 'IN', 'IN',
    'MTNL', 'MTNL', 20, false, false, 'Zendit (`MTNL`) *(Disabled: 0 offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] MTNL (Delhi / Mumbai) -> reloadly (Code: 194, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ba06511f-05c6-4922-9ae9-3536b71bba27' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ba06511f-05c6-4922-9ae9-3536b71bba27', 'reloadly', 'IN', 'IN',
    '194', '194', 30, false, false, 'Reloadly (`194`) *(Disabled: 503 Inactive)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] MTNL (Delhi / Mumbai) -> ding (Code: MNIN, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ba06511f-05c6-4922-9ae9-3536b71bba27' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ba06511f-05c6-4922-9ae9-3536b71bba27', 'ding', 'IN', 'IN',
    'MNIN', 'MNIN', 40, false, false, 'DingConnect (`MNIN`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] AsiaCell -> zendit (Code: AsiaCell, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8fcac8eb-0992-4690-8041-069d142b1c8b' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8fcac8eb-0992-4690-8041-069d142b1c8b', 'zendit', 'IQ', 'IQ',
    'AsiaCell', 'AsiaCell', 10, true, true, 'Zendit (`AsiaCell`) • Offer: `ASIACELL_IQ_001` • Amount: 5,000 IQD • Cost: $4.18 USD Net • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] AsiaCell -> dtone (Code: 42, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8fcac8eb-0992-4690-8041-069d142b1c8b' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8fcac8eb-0992-4690-8041-069d142b1c8b', 'dtone', 'IRQ', 'IRQ',
    '42', '42', 20, false, true, 'DT One (`42`) • Product: `4042` (5k IQD Direct, 1.848 OMR) • Product: `39018` (3k IQD PIN, 1.235 OMR) • Delivery: Direct & Micro PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] AsiaCell -> reloadly (Code: 246, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8fcac8eb-0992-4690-8041-069d142b1c8b' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8fcac8eb-0992-4690-8041-069d142b1c8b', 'reloadly', 'IQ', 'IQ',
    '246', '246', 30, false, true, 'Reloadly (`246`) • Amount: 5,000 IQD • Cost: $6.82 USD Net • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] AsiaCell -> ding (Code: ACIQ, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8fcac8eb-0992-4690-8041-069d142b1c8b' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8fcac8eb-0992-4690-8041-069d142b1c8b', 'ding', 'IQ', 'IQ',
    'ACIQ', 'ACIQ', 40, false, false, 'DingConnect (`ACIQ`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] Zain Iraq -> dtone (Code: 3817, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '580f8049-0cb9-4033-a77e-e71aaf670380' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '580f8049-0cb9-4033-a77e-e71aaf670380', 'dtone', 'IRQ', 'IRQ',
    '3817', '3817', 10, true, true, 'DT One (`3817`) • Product: `38999` (5,000 IQD) • Cost: 2.050 OMR ($5.33 USD) • Validity: 90 Days • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] Zain Iraq -> zendit (Code: Zain, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '580f8049-0cb9-4033-a77e-e71aaf670380' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '580f8049-0cb9-4033-a77e-e71aaf670380', 'zendit', 'IQ', 'IQ',
    'Zain', 'Zain', 20, false, false, 'Zendit (`Zain`) *(Disabled: 0 offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] Zain Iraq -> reloadly (Code: — *(Not Mapped)*, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '580f8049-0cb9-4033-a77e-e71aaf670380' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '580f8049-0cb9-4033-a77e-e71aaf670380', 'reloadly', 'IQ', 'IQ',
    '— *(Not Mapped)*', '— *(Not Mapped)*', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] Zain Iraq -> ding (Code: ZAIQ, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '580f8049-0cb9-4033-a77e-e71aaf670380' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '580f8049-0cb9-4033-a77e-e71aaf670380', 'ding', 'IQ', 'IQ',
    'ZAIQ', 'ZAIQ', 40, false, false, 'DingConnect (`ZAIQ`) *(Disabled: 0 offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] Korek Telecom -> dtone (Code: 2096, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8824c4dd-1be1-4f87-b2bc-a3a4738fd373' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8824c4dd-1be1-4f87-b2bc-a3a4738fd373', 'dtone', 'IRQ', 'IRQ',
    '2096', '2096', 10, true, true, 'DT One (`2096`) • Product: `39011` (5,000 IQD) • Cost: 2.050 OMR ($5.33 USD) • Validity: 40 Days • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] Korek Telecom -> ding (Code: KKIQ, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8824c4dd-1be1-4f87-b2bc-a3a4738fd373' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8824c4dd-1be1-4f87-b2bc-a3a4738fd373', 'ding', 'IQ', 'IQ',
    'KKIQ', 'KKIQ', 20, false, false, 'DingConnect (`KKIQ`/`KRIQ`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] Korek Telecom -> zendit (Code: Korek, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8824c4dd-1be1-4f87-b2bc-a3a4738fd373' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8824c4dd-1be1-4f87-b2bc-a3a4738fd373', 'zendit', 'IQ', 'IQ',
    'Korek', 'Korek', 30, false, false, 'Zendit (`Korek`) *(Disabled: 0 offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] Korek Telecom -> reloadly (Code: — *(Not Mapped)*, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8824c4dd-1be1-4f87-b2bc-a3a4738fd373' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8824c4dd-1be1-4f87-b2bc-a3a4738fd373', 'reloadly', 'IQ', 'IQ',
    '— *(Not Mapped)*', '— *(Not Mapped)*', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Zain Jordan -> dtone (Code: 2093, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '490a2b23-efda-4d06-9317-9ff7b9e1ddfa' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '490a2b23-efda-4d06-9317-9ff7b9e1ddfa', 'dtone', 'JOR', 'JOR',
    '2093', '2093', 10, true, true, 'DT One (`2093`) • Product: `39869` (0.5 JOD) • Cost: 0.510 OMR ($1.33 USD) • Delivery: Direct Airtime (29 SKUs)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Zain Jordan -> zendit (Code: Zain, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '490a2b23-efda-4d06-9317-9ff7b9e1ddfa' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '490a2b23-efda-4d06-9317-9ff7b9e1ddfa', 'zendit', 'JO', 'JO',
    'Zain', 'Zain', 20, false, true, 'Zendit (`Zain`) • Offer: `ZAIN_JORDAN_1_JOD_FEE` • Cost: $2.99 USD (1 JOD) • Delivery: Direct Top-Up (18 SKUs)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Zain Jordan -> ding (Code: ZJJO, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '490a2b23-efda-4d06-9317-9ff7b9e1ddfa' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '490a2b23-efda-4d06-9317-9ff7b9e1ddfa', 'ding', 'JO', 'JO',
    'ZJJO', 'ZJJO', 30, false, true, 'DingConnect (`ZJJO`) • Provider: `ZJJO` • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Zain Jordan -> reloadly (Code: 666, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '490a2b23-efda-4d06-9317-9ff7b9e1ddfa' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '490a2b23-efda-4d06-9317-9ff7b9e1ddfa', 'reloadly', 'JO', 'JO',
    '666', '666', 40, false, false, 'Reloadly (`666`) *(Disabled: High cost / $27.78 USD for 5 JOD)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Orange Jordan -> dtone (Code: 3122, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8568531b-26eb-4793-ab44-e1d80c027abf' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8568531b-26eb-4793-ab44-e1d80c027abf', 'dtone', 'JOR', 'JOR',
    '3122', '3122', 10, true, true, 'DT One (`3122`) • Product: `58694` (1 JOD) • Cost: 1.034 OMR ($2.69 USD) • Delivery: Digital PIN (365d)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Orange Jordan -> zendit (Code: Orange, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8568531b-26eb-4793-ab44-e1d80c027abf' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8568531b-26eb-4793-ab44-e1d80c027abf', 'zendit', 'JO', 'JO',
    'Orange', 'Orange', 20, false, true, 'Zendit (`Orange`) • Offer: `ORANGE_JORDAN_3_JOD_FEE` • Cost: $8.73 USD (3 JOD) • Delivery: Direct Top-Up (4 SKUs)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Orange Jordan -> ding (Code: ORJO, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8568531b-26eb-4793-ab44-e1d80c027abf' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8568531b-26eb-4793-ab44-e1d80c027abf', 'ding', 'JO', 'JO',
    'ORJO', 'ORJO', 30, false, true, 'DingConnect (`ORJO`) • Provider: `ORJO` • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Orange Jordan -> reloadly (Code: 0, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8568531b-26eb-4793-ab44-e1d80c027abf' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8568531b-26eb-4793-ab44-e1d80c027abf', 'reloadly', 'JO', 'JO',
    '0', '0', 40, false, false, 'Reloadly (`0`) *(Disabled: 0 sandbox operators)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Umniah -> reloadly (Code: 1150, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'bd2761bb-020a-4fd7-857c-cc8e4292f330' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'bd2761bb-020a-4fd7-857c-cc8e4292f330', 'reloadly', 'JO', 'JO',
    '1150', '1150', 10, true, true, 'Reloadly (`1150`) • Operator: `1150` (Umniah RTR) • Cost: $4.88 USD (1 JOD) • Delivery: Direct Airtime (Range)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Umniah -> dtone (Code: 690, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'bd2761bb-020a-4fd7-857c-cc8e4292f330' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'bd2761bb-020a-4fd7-857c-cc8e4292f330', 'dtone', 'JOR', 'JOR',
    '690', '690', 20, false, true, 'DT One (`690`) • Product: `58457` (6.85 JOD) • Cost: 6.641 OMR ($17.27 USD) • Delivery: Digital PIN (7 SKUs)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Umniah -> zendit (Code: Umniah, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'bd2761bb-020a-4fd7-857c-cc8e4292f330' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'bd2761bb-020a-4fd7-857c-cc8e4292f330', 'zendit', 'JO', 'JO',
    'Umniah', 'Umniah', 30, false, false, 'Zendit (`Umniah`) *(Disabled: 0 catalog offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Umniah -> ding (Code: Umniah, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'bd2761bb-020a-4fd7-857c-cc8e4292f330' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'bd2761bb-020a-4fd7-857c-cc8e4292f330', 'ding', 'JO', 'JO',
    'Umniah', 'Umniah', 40, false, false, 'DingConnect (`Umniah`) *(Disabled: 0 catalog offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] Zain Kuwait -> dtone (Code: 1812, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2ef9b656-cef7-447e-9c04-80cda1baaa19' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2ef9b656-cef7-447e-9c04-80cda1baaa19', 'dtone', 'KWT', 'KWT',
    '1812', '1812', 10, true, true, 'DT One (`1812`) • Product: `24347` / `12248` (1.5 KWD) • Cost: 2.359 OMR ($6.13 USD) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] Zain Kuwait -> reloadly (Code: 268, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2ef9b656-cef7-447e-9c04-80cda1baaa19' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2ef9b656-cef7-447e-9c04-80cda1baaa19', 'reloadly', 'KW', 'KW',
    '268', '268', 20, false, true, 'Reloadly (`268`) • SKU: Fixed $5.70 Tier (~1.48 KWD) • Cost: $5.53 USD ($5.70 - 3%) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] Zain Kuwait -> zendit (Code: Zain, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2ef9b656-cef7-447e-9c04-80cda1baaa19' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2ef9b656-cef7-447e-9c04-80cda1baaa19', 'zendit', 'KW', 'KW',
    'Zain', 'Zain', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] Zain Kuwait -> ding (Code: ZAKW, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2ef9b656-cef7-447e-9c04-80cda1baaa19' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2ef9b656-cef7-447e-9c04-80cda1baaa19', 'ding', 'KW', 'KW',
    'ZAKW', 'ZAKW', 40, false, false, 'DingConnect (`ZAKW`) *(Disabled: 0 UAT inventory)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] Ooredoo Kuwait -> dtone (Code: 1811, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e4a22bc3-4b05-4e16-a428-cc40b269da78' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e4a22bc3-4b05-4e16-a428-cc40b269da78', 'dtone', 'KWT', 'KWT',
    '1811', '1811', 10, true, true, 'DT One (`1811`) • Product: `24345` / `15206` (1.5 KWD) • Cost: 2.353 OMR ($6.12 USD) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] Ooredoo Kuwait -> reloadly (Code: 1166, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e4a22bc3-4b05-4e16-a428-cc40b269da78' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e4a22bc3-4b05-4e16-a428-cc40b269da78', 'reloadly', 'KW', 'KW',
    '1166', '1166', 20, false, true, 'Reloadly (`1166`) • SKU: Range ($5.70 USD / ~1.48 KWD) • Cost: $5.70 USD • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] Ooredoo Kuwait -> zendit (Code: Ooredoo, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e4a22bc3-4b05-4e16-a428-cc40b269da78' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e4a22bc3-4b05-4e16-a428-cc40b269da78', 'zendit', 'KW', 'KW',
    'Ooredoo', 'Ooredoo', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] Ooredoo Kuwait -> ding (Code: WTKW, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e4a22bc3-4b05-4e16-a428-cc40b269da78' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e4a22bc3-4b05-4e16-a428-cc40b269da78', 'ding', 'KW', 'KW',
    'WTKW', 'WTKW', 40, false, false, 'DingConnect (`WTKW`) *(Disabled: 0 UAT inventory)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] STC Kuwait -> dtone (Code: 1813, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f993b9d0-9974-4986-9eb2-8b0f2e867db7' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f993b9d0-9974-4986-9eb2-8b0f2e867db7', 'dtone', 'KWT', 'KWT',
    '1813', '1813', 10, true, true, 'DT One (`1813`) • Product: `24346` / `12222` (1.5 KWD) • Cost: 2.344 OMR ($6.10 USD) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] STC Kuwait -> reloadly (Code: 267, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f993b9d0-9974-4986-9eb2-8b0f2e867db7' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f993b9d0-9974-4986-9eb2-8b0f2e867db7', 'reloadly', 'KW', 'KW',
    '267', '267', 20, false, true, 'Reloadly (`267`) • SKU: Range ($7.60 USD / ~1.90 KWD) • Cost: $7.37 USD ($7.60 - 3%) • Delivery: Direct Airtime', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] STC Kuwait -> zendit (Code: STC, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f993b9d0-9974-4986-9eb2-8b0f2e867db7' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f993b9d0-9974-4986-9eb2-8b0f2e867db7', 'zendit', 'KW', 'KW',
    'STC', 'STC', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] STC Kuwait -> ding (Code: VIKW, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f993b9d0-9974-4986-9eb2-8b0f2e867db7' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f993b9d0-9974-4986-9eb2-8b0f2e867db7', 'ding', 'KW', 'KW',
    'VIKW', 'VIKW', 40, false, false, 'DingConnect (`VIKW`) *(Disabled: 0 UAT inventory)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] Virgin Mobile Kuwait -> dtone (Code: 1813, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '559c8e3d-bc5a-4e52-a0be-ae20bd28ec6e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '559c8e3d-bc5a-4e52-a0be-ae20bd28ec6e', 'dtone', 'KWT', 'KWT',
    '1813', '1813', 10, true, true, 'DT One (`1813` via STC) • Product: `24346` (1.5 KWD) • Cost: 2.344 OMR ($6.10 USD) • Delivery: Direct / STC Host', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] Virgin Mobile Kuwait -> reloadly (Code: 267, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '559c8e3d-bc5a-4e52-a0be-ae20bd28ec6e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '559c8e3d-bc5a-4e52-a0be-ae20bd28ec6e', 'reloadly', 'KW', 'KW',
    '267', '267', 20, false, true, 'Reloadly (`267` via STC) • SKU: Range ($7.60 USD) • Cost: $7.37 USD • Delivery: Direct / STC Host', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] Virgin Mobile Kuwait -> zendit (Code: Virgin Mobile, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '559c8e3d-bc5a-4e52-a0be-ae20bd28ec6e' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '559c8e3d-bc5a-4e52-a0be-ae20bd28ec6e', 'zendit', 'KW', 'KW',
    'Virgin Mobile', 'Virgin Mobile', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [KW] Virgin Mobile Kuwait -> ding (Code: VIKW, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '559c8e3d-bc5a-4e52-a0be-ae20bd28ec6e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '559c8e3d-bc5a-4e52-a0be-ae20bd28ec6e', 'ding', 'KW', 'KW',
    'VIKW', 'VIKW', 40, false, false, 'DingConnect (`VIKW`) *(Disabled: 0 UAT inventory)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LB] Touch Lebanon -> dtone (Code: 2794, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'a6ae78e4-cff0-4fb0-af4a-ec57e2b2e942' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'a6ae78e4-cff0-4fb0-af4a-ec57e2b2e942', 'dtone', 'LBN', 'LBN',
    '2794', '2794', 10, true, true, 'DT One (`2794`) • Denom: $3.79–$77.28 USD (`44310`–`44317`) • Cost: 2.116–40.970 OMR (~$5.50–$106.52 USD) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LB] Touch Lebanon -> zendit (Code: Touch, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'a6ae78e4-cff0-4fb0-af4a-ec57e2b2e942' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'a6ae78e4-cff0-4fb0-af4a-ec57e2b2e942', 'zendit', 'LB', 'LB',
    'Touch', 'Touch', 20, false, true, 'Zendit (`Touch`) • Denom: 6 Offers (`TOUCH_LB_001_USD`–`006_USD`) • Cost: $6.00–$118.00 USD ($3.79–$77.28 send) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LB] Touch Lebanon -> reloadly (Code: 276, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'a6ae78e4-cff0-4fb0-af4a-ec57e2b2e942' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'a6ae78e4-cff0-4fb0-af4a-ec57e2b2e942', 'reloadly', 'LB', 'LB',
    '276', '276', 30, false, true, 'Reloadly (`276`) • Denom: $25.40 USD • Cost: $25.40 USD • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LB] Touch Lebanon -> ding (Code: TMLB, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'a6ae78e4-cff0-4fb0-af4a-ec57e2b2e942' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'a6ae78e4-cff0-4fb0-af4a-ec57e2b2e942', 'ding', 'LB', 'LB',
    'TMLB', 'TMLB', 40, false, false, 'DingConnect (`TMLB`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LB] Alfa Lebanon -> dtone (Code: 2793, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '5e058bd4-2db8-4dd5-9d1e-ce7443c24218' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '5e058bd4-2db8-4dd5-9d1e-ce7443c24218', 'dtone', 'LBN', 'LBN',
    '2793', '2793', 10, true, true, 'DT One (`2793`) • Denom: $1.22–$77.28 USD (`44471`–`44478`) • Cost: 0.751–40.970 OMR (~$1.95–$106.52 USD) • Delivery: Direct Top-Up (Micro-Refill)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LB] Alfa Lebanon -> zendit (Code: Alfa, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '5e058bd4-2db8-4dd5-9d1e-ce7443c24218' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '5e058bd4-2db8-4dd5-9d1e-ce7443c24218', 'zendit', 'LB', 'LB',
    'Alfa', 'Alfa', 20, false, true, 'Zendit (`Alfa`) • Denom: 7 Offers (`ALFA_LB_001`–`008`) • Cost: $2.50–$161.00 USD ($1.22–$77.28 send) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LB] Alfa Lebanon -> reloadly (Code: 1017, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '5e058bd4-2db8-4dd5-9d1e-ce7443c24218' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '5e058bd4-2db8-4dd5-9d1e-ce7443c24218', 'reloadly', 'LB', 'LB',
    '1017', '1017', 30, false, true, 'Reloadly (`1017`) • Denom: $25.40 USD • Cost: $25.40 USD • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LB] Alfa Lebanon -> ding (Code: AALB, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '5e058bd4-2db8-4dd5-9d1e-ce7443c24218' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '5e058bd4-2db8-4dd5-9d1e-ce7443c24218', 'ding', 'LB', 'LB',
    'AALB', 'AALB', 40, false, false, 'DingConnect (`AALB`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Dialog Axiata -> dtone (Code: 360, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '71785c0a-4d93-4d31-a2ad-58778dfe21de' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '71785c0a-4d93-4d31-a2ad-58778dfe21de', 'dtone', 'LKA', 'LKA',
    '360', '360', 10, true, true, 'DT One (`360`) • Range: 50–10000 LKR (`11294`) • Cost: 0.066 OMR ($0.171 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Dialog Axiata -> reloadly (Code: 472, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '71785c0a-4d93-4d31-a2ad-58778dfe21de' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '71785c0a-4d93-4d31-a2ad-58778dfe21de', 'reloadly', 'LK', 'LK',
    '472', '472', 20, false, true, 'Reloadly (`472` / `1180`) • Fixed: $0.38–$11.40 USD • Data: $0.45–$8.70 USD • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Dialog Axiata -> zendit (Code: Dialog, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '71785c0a-4d93-4d31-a2ad-58778dfe21de' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '71785c0a-4d93-4d31-a2ad-58778dfe21de', 'zendit', 'LK', 'LK',
    'Dialog', 'Dialog', 30, false, true, 'Zendit (`Dialog`) • Offer: `DIALOG_LK_001` • Cost: $6.50 USD (1551 LKR) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Dialog Axiata -> ding (Code: DGLK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '71785c0a-4d93-4d31-a2ad-58778dfe21de' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '71785c0a-4d93-4d31-a2ad-58778dfe21de', 'ding', 'LK', 'LK',
    'DGLK', 'DGLK', 40, false, false, 'DingConnect (`DGLK`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Mobitel Sri Lanka -> dtone (Code: 409, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd9a33c0d-e27e-4ff5-864d-f8cb3c52bb9a' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd9a33c0d-e27e-4ff5-864d-f8cb3c52bb9a', 'dtone', 'LKA', 'LKA',
    '409', '409', 10, true, true, 'DT One (`409`) • Range: 20–10000 LKR (`11296`) • Cost: 0.028 OMR ($0.072 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Mobitel Sri Lanka -> reloadly (Code: 471, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd9a33c0d-e27e-4ff5-864d-f8cb3c52bb9a' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd9a33c0d-e27e-4ff5-864d-f8cb3c52bb9a', 'reloadly', 'LK', 'LK',
    '471', '471', 20, false, true, 'Reloadly (`471`) • Range: 100–3000 LKR ($0.37 USD) • Cost: $0.37–$11.11 USD • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Mobitel Sri Lanka -> zendit (Code: Mobitel, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd9a33c0d-e27e-4ff5-864d-f8cb3c52bb9a' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd9a33c0d-e27e-4ff5-864d-f8cb3c52bb9a', 'zendit', 'LK', 'LK',
    'Mobitel', 'Mobitel', 30, false, true, 'Zendit (`Mobitel`) • Offer: `MOBITEL_LK_5-I` • Cost: $5.60 USD (772 LKR) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Mobitel Sri Lanka -> ding (Code: MSLK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd9a33c0d-e27e-4ff5-864d-f8cb3c52bb9a' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd9a33c0d-e27e-4ff5-864d-f8cb3c52bb9a', 'ding', 'LK', 'LK',
    'MSLK', 'MSLK', 40, false, false, 'DingConnect (`MSLK`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Hutchison Sri Lanka -> dtone (Code: 1609, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '090ef88f-0358-43ed-a866-b0669964a772' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '090ef88f-0358-43ed-a866-b0669964a772', 'dtone', 'LKA', 'LKA',
    '1609', '1609', 10, true, true, 'DT One (`1609`) • Range: 50–3000 LKR (`11295`) • Cost: 0.068 OMR ($0.177 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Hutchison Sri Lanka -> reloadly (Code: 475, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '090ef88f-0358-43ed-a866-b0669964a772' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '090ef88f-0358-43ed-a866-b0669964a772', 'reloadly', 'LK', 'LK',
    '475', '475', 20, false, true, 'Reloadly (`475` / `1181`) • Range: 100–3000 LKR ($0.63 USD) • Data: $0.30–$3.00 USD • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Hutchison Sri Lanka -> zendit (Code: Hutch, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '090ef88f-0358-43ed-a866-b0669964a772' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '090ef88f-0358-43ed-a866-b0669964a772', 'zendit', 'LK', 'LK',
    'Hutch', 'Hutch', 30, false, true, 'Zendit (`Hutch`) • Offer: `HUTCH_LK_5-I` • Cost: $5.50 USD (792 LKR) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Hutchison Sri Lanka -> ding (Code: HSLK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '090ef88f-0358-43ed-a866-b0669964a772' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '090ef88f-0358-43ed-a866-b0669964a772', 'ding', 'LK', 'LK',
    'HSLK', 'HSLK', 40, false, false, 'DingConnect (`HSLK`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Airtel Sri Lanka -> dtone (Code: 360, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7731b015-3681-4543-b557-9785665c0f73' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7731b015-3681-4543-b557-9785665c0f73', 'dtone', 'LKA', 'LKA',
    '360', '360', 10, true, true, 'DT One (`360`) • Range: 50–10000 LKR (`11294`) • Cost: 0.066 OMR ($0.171 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Airtel Sri Lanka -> reloadly (Code: 472, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7731b015-3681-4543-b557-9785665c0f73' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7731b015-3681-4543-b557-9785665c0f73', 'reloadly', 'LK', 'LK',
    '472', '472', 20, false, true, 'Reloadly (`472`) • Fixed: $0.38–$11.40 USD • Cost: $0.38 USD (100 LKR) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Airtel Sri Lanka -> zendit (Code: Dialog, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7731b015-3681-4543-b557-9785665c0f73' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7731b015-3681-4543-b557-9785665c0f73', 'zendit', 'LK', 'LK',
    'Dialog', 'Dialog', 30, false, true, 'Zendit (`Dialog`) • Offer: `DIALOG_LK_001` • Cost: $6.50 USD (1551 LKR) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Airtel Sri Lanka -> ding (Code: DGLK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7731b015-3681-4543-b557-9785665c0f73' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7731b015-3681-4543-b557-9785665c0f73', 'ding', 'LK', 'LK',
    'DGLK', 'DGLK', 40, false, false, 'DingConnect (`DGLK`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Maroc Telecom -> dtone (Code: 1533, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '98d1acf2-5615-4008-bfb5-abf95dc22edc' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '98d1acf2-5615-4008-bfb5-abf95dc22edc', 'dtone', 'MAR', 'MAR',
    '1533', '1533', 10, true, true, 'DT One (`1533`) • Fixed: 5–300 MAD (`4073`+) • Cost: 0.242 OMR ($0.629 USD) • Delivery: Direct Recharge & Pass *3 Data', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Maroc Telecom -> reloadly (Code: 311, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '98d1acf2-5615-4008-bfb5-abf95dc22edc' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '98d1acf2-5615-4008-bfb5-abf95dc22edc', 'reloadly', 'MA', 'MA',
    '311', '311', 20, false, true, 'Reloadly (`311` / `310`) • Fixed: 5–300 MAD ($0.63 USD) • Cost: $0.63–$37.50 USD • Delivery: Direct Airtime & Data', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Maroc Telecom -> ding (Code: MOMA, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '98d1acf2-5615-4008-bfb5-abf95dc22edc' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '98d1acf2-5615-4008-bfb5-abf95dc22edc', 'ding', 'MA', 'MA',
    'MOMA', 'MOMA', 30, false, false, 'DingConnect (`MOMA` / `0MMA`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Maroc Telecom -> zendit (Code: MarocTelecom, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '98d1acf2-5615-4008-bfb5-abf95dc22edc' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '98d1acf2-5615-4008-bfb5-abf95dc22edc', 'zendit', 'MA', 'MA',
    'MarocTelecom', 'MarocTelecom', 40, false, false, 'Zendit (`MarocTelecom`) *(Disabled: 0 Sandbox offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Orange Morocco -> dtone (Code: 387, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '223bb67b-843a-4b54-829e-6a91a720bf47' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '223bb67b-843a-4b54-829e-6a91a720bf47', 'dtone', 'MAR', 'MAR',
    '387', '387', 10, true, true, 'DT One (`387`) • Fixed: 6–330 MAD (`50285`+) • Cost: 0.302 OMR ($0.785 USD) • Delivery: Direct Recharge & Social', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Orange Morocco -> reloadly (Code: 313, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '223bb67b-843a-4b54-829e-6a91a720bf47' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '223bb67b-843a-4b54-829e-6a91a720bf47', 'reloadly', 'MA', 'MA',
    '313', '313', 20, false, true, 'Reloadly (`313` / `690` / `309`) • Range: 36.86–330 MAD ($4.38 USD) • Cost: $4.16–$37.26 USD • Delivery: Direct Airtime, Bundles & Data', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Orange Morocco -> ding (Code: ORMA, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '223bb67b-843a-4b54-829e-6a91a720bf47' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '223bb67b-843a-4b54-829e-6a91a720bf47', 'ding', 'MA', 'MA',
    'ORMA', 'ORMA', 30, false, false, 'DingConnect (`ORMA`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Orange Morocco -> zendit (Code: Orange, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '223bb67b-843a-4b54-829e-6a91a720bf47' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '223bb67b-843a-4b54-829e-6a91a720bf47', 'zendit', 'MA', 'MA',
    'Orange', 'Orange', 40, false, false, 'Zendit (`Orange`) *(Disabled: 0 Sandbox offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Inwi -> dtone (Code: 1711, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd10adfd9-ee64-43b1-abe3-3d54373d5c4c' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd10adfd9-ee64-43b1-abe3-3d54373d5c4c', 'dtone', 'MAR', 'MAR',
    '1711', '1711', 10, true, true, 'DT One (`1711`) • Fixed: 5–300 MAD (`16801`+) • Cost: 0.245 OMR ($0.637 USD) • Delivery: Direct Recharge & Pass *3 Data', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Inwi -> reloadly (Code: 312, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd10adfd9-ee64-43b1-abe3-3d54373d5c4c' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd10adfd9-ee64-43b1-abe3-3d54373d5c4c', 'reloadly', 'MA', 'MA',
    '312', '312', 20, false, true, 'Reloadly (`312` / `308` / `688`) • Fixed: 5–200 MAD ($0.60 USD) • Cost: $0.570–$22.182 USD • Delivery: Direct Airtime & Data', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Inwi -> ding (Code: INMA, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd10adfd9-ee64-43b1-abe3-3d54373d5c4c' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd10adfd9-ee64-43b1-abe3-3d54373d5c4c', 'ding', 'MA', 'MA',
    'INMA', 'INMA', 30, false, false, 'DingConnect (`INMA` / `I0MA`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Inwi -> zendit (Code: Inwi, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd10adfd9-ee64-43b1-abe3-3d54373d5c4c' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd10adfd9-ee64-43b1-abe3-3d54373d5c4c', 'zendit', 'MA', 'MA',
    'Inwi', 'Inwi', 40, false, false, 'Zendit (`Inwi`) *(Disabled: 0 Sandbox offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Ncell -> dtone (Code: 1442, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895', 'dtone', 'NPL', 'NPL',
    '1442', '1442', 10, true, true, 'DT One (`1442`) • Range: 50–3000 NPR (`11938`) • Cost: 0.093–0.154 OMR ($0.24–$0.40 USD) • Delivery: Direct Recharge & Data', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Ncell -> reloadly (Code: 328, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895', 'reloadly', 'NP', 'NP',
    '328', '328', 20, false, true, 'Reloadly (`328` / `1121`) • Range: 50–5000 NPR ($0.38 USD) • Cost: $0.2185–$37.72 USD • Delivery: Direct Airtime & Data', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Ncell -> zendit (Code: Ncell, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895', 'zendit', 'NP', 'NP',
    'Ncell', 'Ncell', 30, false, true, 'Zendit (`Ncell`) • Offers: `NCELL_NP_6-I` to `24-I` • Cost: $5.60–$22.30 USD • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Ncell -> ding (Code: NCNP, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895', 'ding', 'NP', 'NP',
    'NCNP', 'NCNP', 40, false, false, 'DingConnect (`NCNP`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Nepal Telecom -> dtone (Code: 1443, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '6a49574b-b1fa-4a1b-85bc-b9595bb5bda4' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '6a49574b-b1fa-4a1b-85bc-b9595bb5bda4', 'dtone', 'NPL', 'NPL',
    '1443', '1443', 10, true, true, 'DT One (`1443`) • Range: 10–10000 NPR (`11939`) • Cost: 0.031–1.531 OMR ($0.08–$3.98 USD) • Delivery: Direct Recharge & Micro-Rail', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Nepal Telecom -> reloadly (Code: 326, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '6a49574b-b1fa-4a1b-85bc-b9595bb5bda4' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '6a49574b-b1fa-4a1b-85bc-b9595bb5bda4', 'reloadly', 'NP', 'NP',
    '326', '326', 20, false, true, 'Reloadly (`326` / `1123`) • Range: 50–20000 NPR ($0.38 USD) • Cost: $0.1615–$150.86 USD • Delivery: Direct Airtime & Data', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Nepal Telecom -> zendit (Code: NTCGSM, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '6a49574b-b1fa-4a1b-85bc-b9595bb5bda4' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '6a49574b-b1fa-4a1b-85bc-b9595bb5bda4', 'zendit', 'NP', 'NP',
    'NTCGSM', 'NTCGSM', 30, false, true, 'Zendit (`NTCGSM`) • Offers: `NTCGSM_NP_2.5-I` to `12-I` • Cost: $2.00–$9.60 USD • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Nepal Telecom -> ding (Code: NENP, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '6a49574b-b1fa-4a1b-85bc-b9595bb5bda4' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '6a49574b-b1fa-4a1b-85bc-b9595bb5bda4', 'ding', 'NP', 'NP',
    'NENP', 'NENP', 40, false, false, 'DingConnect (`NENP`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Smart Cell -> dtone (Code: *(Not Listed / Decommissioned)*, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b2b70951-371d-4cf2-ab68-401c57498aec' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b2b70951-371d-4cf2-ab68-401c57498aec', 'dtone', 'NPL', 'NPL',
    '*(Not Listed / Decommissioned)*', '*(Not Listed / Decommissioned)*', 40, false, false, '🔴 Not Mapped', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Smart Cell -> reloadly (Code: 805, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b2b70951-371d-4cf2-ab68-401c57498aec' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b2b70951-371d-4cf2-ab68-401c57498aec', 'reloadly', 'NP', 'NP',
    '805', '805', 20, false, false, 'Reloadly (`805`) *(Disabled: Decommissioned in Nepal)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Smart Cell -> zendit (Code: *(Not Listed)*, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b2b70951-371d-4cf2-ab68-401c57498aec' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b2b70951-371d-4cf2-ab68-401c57498aec', 'zendit', 'NP', 'NP',
    '*(Not Listed)*', '*(Not Listed)*', 40, false, false, '🔴 Not Mapped', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Smart Cell -> ding (Code: *(Not Listed)*, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b2b70951-371d-4cf2-ab68-401c57498aec' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b2b70951-371d-4cf2-ab68-401c57498aec', 'ding', 'NP', 'NP',
    '*(Not Listed)*', '*(Not Listed)*', 40, false, false, '🔴 Not Mapped', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Omantel -> reloadly (Code: 348, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8e789341-fe2a-402c-842c-0d769ccfc516' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8e789341-fe2a-402c-842c-0d769ccfc516', 'reloadly', 'OM', 'OM',
    '348', '348', 10, true, true, 'Reloadly (`348`) • Operator: `348` • Cost: $2.955 USD (1 OMR PIN) • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Omantel -> dtone (Code: 2695, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8e789341-fe2a-402c-842c-0d769ccfc516' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8e789341-fe2a-402c-842c-0d769ccfc516', 'dtone', 'OMN', 'OMN',
    '2695', '2695', 20, false, true, 'DT One (`2695`) • Product: `17091` (1 OMR) • Cost: 1.240 OMR ($3.224 USD) • Delivery: PIN & Hayyak Packs', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Omantel -> ding (Code: OMOM, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8e789341-fe2a-402c-842c-0d769ccfc516' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8e789341-fe2a-402c-842c-0d769ccfc516', 'ding', 'OM', 'OM',
    'OMOM', 'OMOM', 30, false, true, 'DingConnect (`OMOM`) • Provider: `OMOM` • Delivery: Direct / PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Omantel -> zendit (Code: Omantel, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8e789341-fe2a-402c-842c-0d769ccfc516' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8e789341-fe2a-402c-842c-0d769ccfc516', 'zendit', 'OM', 'OM',
    'Omantel', 'Omantel', 40, false, false, 'Zendit (`Omantel`) *(Disabled: 0 catalog offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Ooredoo Oman -> reloadly (Code: 1168, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '6c575769-c34a-46b8-865d-398be2088e24' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '6c575769-c34a-46b8-865d-398be2088e24', 'reloadly', 'OM', 'OM',
    '1168', '1168', 10, true, true, 'Reloadly (`1168`) • Operator: `1168` • Cost: $2.95 USD (1.14 OMR) • Delivery: Direct Airtime Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Ooredoo Oman -> dtone (Code: 2883, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '6c575769-c34a-46b8-865d-398be2088e24' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '6c575769-c34a-46b8-865d-398be2088e24', 'dtone', 'OMN', 'OMN',
    '2883', '2883', 20, false, true, 'DT One (`2883`) • Product: `18802` (1 OMR) • Cost: 1.228 OMR ($3.193 USD) • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Ooredoo Oman -> ding (Code: OOOM, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '6c575769-c34a-46b8-865d-398be2088e24' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '6c575769-c34a-46b8-865d-398be2088e24', 'ding', 'OM', 'OM',
    'OOOM', 'OOOM', 30, false, true, 'DingConnect (`OOOM`) • Provider: `OOOM` • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Ooredoo Oman -> zendit (Code: Ooredoo, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '6c575769-c34a-46b8-865d-398be2088e24' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '6c575769-c34a-46b8-865d-398be2088e24', 'zendit', 'OM', 'OM',
    'Ooredoo', 'Ooredoo', 40, false, false, 'Zendit (`Ooredoo`) *(Disabled: 0 catalog offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Vodafone Oman -> ding (Code: VFOM, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd5a330e3-888f-4ae7-a487-c70ba3435abb' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd5a330e3-888f-4ae7-a487-c70ba3435abb', 'ding', 'OM', 'OM',
    'VFOM', 'VFOM', 10, true, true, 'DingConnect (`VFOM`) • Provider: `VFOM` • Delivery: Primary Mapped Route', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Vodafone Oman -> dtone (Code: Vodafone, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd5a330e3-888f-4ae7-a487-c70ba3435abb' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd5a330e3-888f-4ae7-a487-c70ba3435abb', 'dtone', 'OMN', 'OMN',
    'Vodafone', 'Vodafone', 20, false, false, '🔴 Disabled (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Vodafone Oman -> reloadly (Code: Vodafone, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd5a330e3-888f-4ae7-a487-c70ba3435abb' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd5a330e3-888f-4ae7-a487-c70ba3435abb', 'reloadly', 'OM', 'OM',
    'Vodafone', 'Vodafone', 30, false, false, '🔴 Disabled (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Vodafone Oman -> zendit (Code: Vodafone, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd5a330e3-888f-4ae7-a487-c70ba3435abb' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd5a330e3-888f-4ae7-a487-c70ba3435abb', 'zendit', 'OM', 'OM',
    'Vodafone', 'Vodafone', 40, false, false, '🔴 Disabled (`priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] FRiENDi Mobile Oman -> reloadly (Code: 348, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '02ba945c-9479-48d4-9852-7cc5030ccede' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '02ba945c-9479-48d4-9852-7cc5030ccede', 'reloadly', 'OM', 'OM',
    '348', '348', 20, false, true, 'Reloadly (`348`) • Delivery: PIN Failover', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] FRiENDi Mobile Oman -> ding (Code: OMOM, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '02ba945c-9479-48d4-9852-7cc5030ccede' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '02ba945c-9479-48d4-9852-7cc5030ccede', 'ding', 'OM', 'OM',
    'OMOM', 'OMOM', 30, false, true, 'DingConnect (`OMOM`) • Delivery: Direct / PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] FRiENDi Mobile Oman -> zendit (Code: Friendi, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '02ba945c-9479-48d4-9852-7cc5030ccede' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '02ba945c-9479-48d4-9852-7cc5030ccede', 'zendit', 'OM', 'OM',
    'Friendi', 'Friendi', 40, false, false, '🔴 Disabled (`priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] FRiENDi Mobile Oman -> dtone (Code: Serviced via Omantel Rails, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '02ba945c-9479-48d4-9852-7cc5030ccede' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '02ba945c-9479-48d4-9852-7cc5030ccede', 'dtone', 'OMN', 'OMN',
    'Serviced via Omantel Rails', 'Serviced via Omantel Rails', 10, true, true, '🟢 Primary PIN Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Renna Mobile -> dtone (Code: 2697, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '67ae4e83-9b19-4168-9140-a83ccb0af44b' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '67ae4e83-9b19-4168-9140-a83ccb0af44b', 'dtone', 'OMN', 'OMN',
    '2697', '2697', 10, true, true, 'DT One (`2697`) • Product: `42651` (0.3 OMR) • Cost: 0.370 OMR ($0.962 USD) • Delivery: Micro-PIN Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Renna Mobile -> reloadly (Code: 349, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '67ae4e83-9b19-4168-9140-a83ccb0af44b' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '67ae4e83-9b19-4168-9140-a83ccb0af44b', 'reloadly', 'OM', 'OM',
    '349', '349', 20, false, true, 'Reloadly (`349`) • Operator: `349` • Cost: $1.478 USD (0.58 OMR) • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Red Bull Mobile Oman -> dtone (Code: 3444, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '76923a26-bb55-497a-8da8-b2248f8fcc0f' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '76923a26-bb55-497a-8da8-b2248f8fcc0f', 'dtone', 'OMN', 'OMN',
    '3444', '3444', 10, true, true, 'DT One (`3444`) • Product: `42652` (0.3 OMR) • Cost: 0.369 OMR ($0.959 USD) • Delivery: Exclusive Micro-PIN Route', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Red Bull Mobile Oman -> reloadly (Code: RedBull, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '76923a26-bb55-497a-8da8-b2248f8fcc0f' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '76923a26-bb55-497a-8da8-b2248f8fcc0f', 'reloadly', 'OM', 'OM',
    'RedBull', 'RedBull', 20, false, false, '🔴 Disabled (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Red Bull Mobile Oman -> ding (Code: RedBull, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '76923a26-bb55-497a-8da8-b2248f8fcc0f' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '76923a26-bb55-497a-8da8-b2248f8fcc0f', 'ding', 'OM', 'OM',
    'RedBull', 'RedBull', 30, false, false, '🔴 Disabled (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Red Bull Mobile Oman -> zendit (Code: RedBull, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '76923a26-bb55-497a-8da8-b2248f8fcc0f' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '76923a26-bb55-497a-8da8-b2248f8fcc0f', 'zendit', 'OM', 'OM',
    'RedBull', 'RedBull', 40, false, false, '🔴 Disabled (`priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Jazz -> dtone (Code: 400, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ed074f20-1809-4665-abfe-9c571d11b4e3' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ed074f20-1809-4665-abfe-9c571d11b4e3', 'dtone', 'PAK', 'PAK',
    '400', '400', 10, true, true, 'DT One (`400`) • Product: `3760` (100 PKR) • Cost: 0.168 OMR ($0.44 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Jazz -> reloadly (Code: 354, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ed074f20-1809-4665-abfe-9c571d11b4e3' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ed074f20-1809-4665-abfe-9c571d11b4e3', 'reloadly', 'PK', 'PK',
    '354', '354', 20, false, true, 'Reloadly (`354`) • Range: 200–10000 PKR • Cost: $0.78 USD (200 PKR net) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Jazz -> zendit (Code: Jazz, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ed074f20-1809-4665-abfe-9c571d11b4e3' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ed074f20-1809-4665-abfe-9c571d11b4e3', 'zendit', 'PK', 'PK',
    'Jazz', 'Jazz', 30, false, true, 'Zendit (`Jazz`) • Offer: `JAZZ_PK_OPEN` • Cost: $0.38 USD (98 PKR min) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Jazz -> ding (Code: MBPK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ed074f20-1809-4665-abfe-9c571d11b4e3' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ed074f20-1809-4665-abfe-9c571d11b4e3', 'ding', 'PK', 'PK',
    'MBPK', 'MBPK', 40, false, false, 'DingConnect (`MBPK`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Telenor Pakistan -> dtone (Code: 655, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1b30419d-d8cc-4e5c-ba69-69ad1db1d827' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1b30419d-d8cc-4e5c-ba69-69ad1db1d827', 'dtone', 'PAK', 'PAK',
    '655', '655', 10, true, true, 'DT One (`655`) • Product: `3378` (100 PKR) • Cost: 0.168 OMR ($0.44 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Telenor Pakistan -> reloadly (Code: 353, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1b30419d-d8cc-4e5c-ba69-69ad1db1d827' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1b30419d-d8cc-4e5c-ba69-69ad1db1d827', 'reloadly', 'PK', 'PK',
    '353', '353', 20, false, true, 'Reloadly (`353`) • Range: 100–5000 PKR • Cost: $0.39 USD (100 PKR net) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Telenor Pakistan -> zendit (Code: Telenor, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1b30419d-d8cc-4e5c-ba69-69ad1db1d827' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1b30419d-d8cc-4e5c-ba69-69ad1db1d827', 'zendit', 'PK', 'PK',
    'Telenor', 'Telenor', 30, false, true, 'Zendit (`Telenor`) • Offer: `TELENOR_PK_OPEN` • Cost: $0.30 USD (78 PKR min) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Telenor Pakistan -> ding (Code: TPPK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1b30419d-d8cc-4e5c-ba69-69ad1db1d827' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1b30419d-d8cc-4e5c-ba69-69ad1db1d827', 'ding', 'PK', 'PK',
    'TPPK', 'TPPK', 40, false, false, 'DingConnect (`TPPK`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Zong -> dtone (Code: 1515, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd11255ef-6919-4280-91bd-70199fba5253' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd11255ef-6919-4280-91bd-70199fba5253', 'dtone', 'PAK', 'PAK',
    '1515', '1515', 10, true, true, 'DT One (`1515`) • Product: `3923` (100 PKR) • Cost: 0.168 OMR ($0.44 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Zong -> reloadly (Code: 352, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd11255ef-6919-4280-91bd-70199fba5253' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd11255ef-6919-4280-91bd-70199fba5253', 'reloadly', 'PK', 'PK',
    '352', '352', 20, false, true, 'Reloadly (`352`) • Range: 100–10000 PKR • Cost: $0.39 USD (100 PKR net) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Zong -> zendit (Code: Zong, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd11255ef-6919-4280-91bd-70199fba5253' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd11255ef-6919-4280-91bd-70199fba5253', 'zendit', 'PK', 'PK',
    'Zong', 'Zong', 30, false, true, 'Zendit (`Zong`) • Offer: `ZONG_PK_OPEN` • Cost: $0.30 USD (78 PKR min) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Zong -> ding (Code: ZNPK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd11255ef-6919-4280-91bd-70199fba5253' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd11255ef-6919-4280-91bd-70199fba5253', 'ding', 'PK', 'PK',
    'ZNPK', 'ZNPK', 40, false, false, 'DingConnect (`ZNPK`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Ufone -> dtone (Code: 486, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'c9610c03-e9b0-4652-824e-05819c750434' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'c9610c03-e9b0-4652-824e-05819c750434', 'dtone', 'PAK', 'PAK',
    '486', '486', 10, true, true, 'DT One (`486`) • Product: `2788` (100 PKR) • Cost: 0.168 OMR ($0.44 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Ufone -> reloadly (Code: 355, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'c9610c03-e9b0-4652-824e-05819c750434' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'c9610c03-e9b0-4652-824e-05819c750434', 'reloadly', 'PK', 'PK',
    '355', '355', 20, false, true, 'Reloadly (`355`) • Range: 100–10000 PKR • Cost: $0.39 USD (100 PKR net) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Ufone -> zendit (Code: Ufone, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'c9610c03-e9b0-4652-824e-05819c750434' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'c9610c03-e9b0-4652-824e-05819c750434', 'zendit', 'PK', 'PK',
    'Ufone', 'Ufone', 30, false, true, 'Zendit (`Ufone`) • Offer: `UFONE_PK_OPEN` • Cost: $0.37 USD (99 PKR min) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Ufone -> ding (Code: UFPK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'c9610c03-e9b0-4652-824e-05819c750434' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'c9610c03-e9b0-4652-824e-05819c750434', 'ding', 'PK', 'PK',
    'UFPK', 'UFPK', 40, false, false, 'DingConnect (`UFPK`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Globe Telecom -> dtone (Code: 246, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4', 'dtone', 'PHL', 'PHL',
    '246', '246', 10, true, true, 'DT One (`246`) • Product: `12824` (10 PHP) • Cost: 0.076 OMR ($0.198 USD) • Delivery: Direct Micro-Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Globe Telecom -> reloadly (Code: 371, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4', 'reloadly', 'PH', 'PH',
    '371', '371', 20, false, true, 'Reloadly (`371`) • Operator: `371` • Cost: $0.18 USD (10 PHP) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Globe Telecom -> zendit (Code: Globe, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4', 'zendit', 'PH', 'PH',
    'Globe', 'Globe', 30, false, true, 'Zendit (`Globe`) • Offer: `GLOBE_PH_8_FEE` • Cost: $7.76 USD (400 PHP) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Globe Telecom -> ding (Code: GBPH, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4', 'ding', 'PH', 'PH',
    'GBPH', 'GBPH', 40, false, false, 'DingConnect (`GBPH`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Smart Communications -> dtone (Code: 570, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f259b40b-3d06-4fb2-b765-edb0d01df788' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f259b40b-3d06-4fb2-b765-edb0d01df788', 'dtone', 'PHL', 'PHL',
    '570', '570', 10, true, true, 'DT One (`570`) • Product: `22752` (5 PHP) / `7684` (10 PHP) • Cost: 0.037–0.074 OMR ($0.10–$0.19 USD) • Delivery: Direct Micro-Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Smart Communications -> reloadly (Code: 372, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f259b40b-3d06-4fb2-b765-edb0d01df788' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f259b40b-3d06-4fb2-b765-edb0d01df788', 'reloadly', 'PH', 'PH',
    '372', '372', 20, false, true, 'Reloadly (`372`) • Operator: `372` • Cost: $0.27 USD (14.74 PHP) • Delivery: Direct Range', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Smart Communications -> zendit (Code: Smart, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f259b40b-3d06-4fb2-b765-edb0d01df788' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f259b40b-3d06-4fb2-b765-edb0d01df788', 'zendit', 'PH', 'PH',
    'Smart', 'Smart', 30, false, true, 'Zendit (`Smart`) • Offer: `SMART_PH_6_FEE` • Cost: $6.20 USD (300 PHP) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Smart Communications -> ding (Code: SMPH, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f259b40b-3d06-4fb2-b765-edb0d01df788' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f259b40b-3d06-4fb2-b765-edb0d01df788', 'ding', 'PH', 'PH',
    'SMPH', 'SMPH', 40, false, false, 'DingConnect (`SMPH`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] DITO Telecommunity -> zendit (Code: Dito, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '0ca2d774-fca1-4d2f-845a-f38babee4adc' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '0ca2d774-fca1-4d2f-845a-f38babee4adc', 'zendit', 'PH', 'PH',
    'Dito', 'Dito', 10, true, true, 'Zendit (`Dito`) • Offer: `DITO_PH_001` • Cost: $4.52 USD (200 PHP) • Delivery: Exclusive Active Route', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] DITO Telecommunity -> reloadly (Code: 1182, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '0ca2d774-fca1-4d2f-845a-f38babee4adc' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '0ca2d774-fca1-4d2f-845a-f38babee4adc', 'reloadly', 'PH', 'PH',
    '1182', '1182', 20, false, false, 'Reloadly (`1182`) *(Disabled in sandbox: 409)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] DITO Telecommunity -> ding (Code: DWPH, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '0ca2d774-fca1-4d2f-845a-f38babee4adc' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '0ca2d774-fca1-4d2f-845a-f38babee4adc', 'ding', 'PH', 'PH',
    'DWPH', 'DWPH', 40, false, false, 'DingConnect (`DWPH`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] TM (Touch Mobile) -> dtone (Code: 3128, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'dce6f8a2-bdf1-4e37-be40-7db94d97b4de' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'dce6f8a2-bdf1-4e37-be40-7db94d97b4de', 'dtone', 'PHL', 'PHL',
    '3128', '3128', 10, true, true, 'DT One (`3128`) • Product: `23309` (10 PHP) • Cost: 0.076 OMR ($0.198 USD) • Delivery: Direct Micro-Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] TM (Touch Mobile) -> reloadly (Code: 723, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'dce6f8a2-bdf1-4e37-be40-7db94d97b4de' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'dce6f8a2-bdf1-4e37-be40-7db94d97b4de', 'reloadly', 'PH', 'PH',
    '723', '723', 20, false, true, 'Reloadly (`723`) • Operator: `723` • Cost: $0.18 USD (10 PHP) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] TM (Touch Mobile) -> zendit (Code: TouchMobile, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'dce6f8a2-bdf1-4e37-be40-7db94d97b4de' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'dce6f8a2-bdf1-4e37-be40-7db94d97b4de', 'zendit', 'PH', 'PH',
    'TouchMobile', 'TouchMobile', 30, false, true, 'Zendit (`TouchMobile`) • Offer: `TOUCHMOBILE_PH_001` • Cost: $3.39 USD (150 PHP) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] TM (Touch Mobile) -> ding (Code: TMPH, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'dce6f8a2-bdf1-4e37-be40-7db94d97b4de' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'dce6f8a2-bdf1-4e37-be40-7db94d97b4de', 'ding', 'PH', 'PH',
    'TMPH', 'TMPH', 40, false, false, 'DingConnect (`TMPH`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] TNT (Talk 'N Text) -> dtone (Code: 2897, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8d3b02aa-f69b-4f06-ab39-c6edb703f875' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8d3b02aa-f69b-4f06-ab39-c6edb703f875', 'dtone', 'PHL', 'PHL',
    '2897', '2897', 10, true, true, 'DT One (`2897`) • Product: `18948` (5 PHP) / `18936` (10 PHP) • Cost: 0.037–0.074 OMR ($0.10–$0.19 USD) • Delivery: Direct Micro-Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] TNT (Talk 'N Text) -> reloadly (Code: 378, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8d3b02aa-f69b-4f06-ab39-c6edb703f875' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8d3b02aa-f69b-4f06-ab39-c6edb703f875', 'reloadly', 'PH', 'PH',
    '378', '378', 20, false, true, 'Reloadly (`378`) • Operator: `378` • Cost: $0.18 USD (10 PHP) • Delivery: Direct / PIN', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] TNT (Talk 'N Text) -> zendit (Code: TNT, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8d3b02aa-f69b-4f06-ab39-c6edb703f875' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8d3b02aa-f69b-4f06-ab39-c6edb703f875', 'zendit', 'PH', 'PH',
    'TNT', 'TNT', 30, false, true, 'Zendit (`TNT`) • Offer: `TNT_PH_001` • Cost: $5.42 USD (318 PHP) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] TNT (Talk 'N Text) -> ding (Code: STPH, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8d3b02aa-f69b-4f06-ab39-c6edb703f875' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8d3b02aa-f69b-4f06-ab39-c6edb703f875', 'ding', 'PH', 'PH',
    'STPH', 'STPH', 40, false, false, 'DingConnect (`STPH`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [QA] Ooredoo Qatar -> reloadly (Code: 396, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'a6afbb6c-9a9e-4af5-8b4e-c40b87ceb4cb' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'a6afbb6c-9a9e-4af5-8b4e-c40b87ceb4cb', 'reloadly', 'QA', 'QA',
    '396', '396', 10, true, true, 'Reloadly (`396`) • Denom: 100–200 QAR • Cost: $39.76–$79.52 USD (1% disc) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [QA] Ooredoo Qatar -> dtone (Code: 511, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'a6afbb6c-9a9e-4af5-8b4e-c40b87ceb4cb' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'a6afbb6c-9a9e-4af5-8b4e-c40b87ceb4cb', 'dtone', 'QAT', 'QAT',
    '511', '511', 20, false, true, 'DT One (`511`) • Denom: 80–150 QAR (`33349`/`1738`) • Cost: 10.252–19.221 OMR • Delivery: Data PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [QA] Ooredoo Qatar -> zendit (Code: Ooredoo, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'a6afbb6c-9a9e-4af5-8b4e-c40b87ceb4cb' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'a6afbb6c-9a9e-4af5-8b4e-c40b87ceb4cb', 'zendit', 'QA', 'QA',
    'Ooredoo', 'Ooredoo', 30, false, false, 'Zendit (`Ooredoo`) *(Disabled: 0 catalog offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [QA] Ooredoo Qatar -> ding (Code: OOQA, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'a6afbb6c-9a9e-4af5-8b4e-c40b87ceb4cb' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'a6afbb6c-9a9e-4af5-8b4e-c40b87ceb4cb', 'ding', 'QA', 'QA',
    'OOQA', 'OOQA', 40, false, false, 'DingConnect (`OOQA`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [QA] Vodafone Qatar -> dtone (Code: 2722, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '6a16b6f7-6036-4c96-b928-be8b286442fc' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '6a16b6f7-6036-4c96-b928-be8b286442fc', 'dtone', 'QAT', 'QAT',
    '2722', '2722', 10, true, true, 'DT One (`2722`) • Denom: 10–300 QAR (`17355`–`17362`) • Cost: 1.288–38.664 OMR (~$3.35+ USD) • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [QA] Vodafone Qatar -> reloadly (Code: 395, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '6a16b6f7-6036-4c96-b928-be8b286442fc' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '6a16b6f7-6036-4c96-b928-be8b286442fc', 'reloadly', 'QA', 'QA',
    '395', '395', 20, false, true, 'Reloadly (`395`) • Denom: $3.60–$35.60 USD • Cost: $3.564–$35.244 USD (1% disc) • Delivery: Digital PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [QA] Vodafone Qatar -> zendit (Code: Vodafone, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '6a16b6f7-6036-4c96-b928-be8b286442fc' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '6a16b6f7-6036-4c96-b928-be8b286442fc', 'zendit', 'QA', 'QA',
    'Vodafone', 'Vodafone', 30, false, false, 'Zendit (`Vodafone`) *(Disabled: 0 catalog offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [QA] Vodafone Qatar -> ding (Code: VFQA, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '6a16b6f7-6036-4c96-b928-be8b286442fc' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '6a16b6f7-6036-4c96-b928-be8b286442fc', 'ding', 'QA', 'QA',
    'VFQA', 'VFQA', 40, false, false, 'DingConnect (`VFQA`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] STC -> zendit (Code: STC, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'da1c57b4-5276-4814-ade4-1d5a421bc29e' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'da1c57b4-5276-4814-ade4-1d5a421bc29e', 'zendit', 'SA', 'SA',
    'STC', 'STC', 10, true, true, 'Zendit (`STC`) • Offer: `STC_SA_001_USD` (20 SAR) • Cost: $7.10 USD • Delivery: Direct Airtime (Automated)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] STC -> ding (Code: XCSA, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'da1c57b4-5276-4814-ade4-1d5a421bc29e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'da1c57b4-5276-4814-ade4-1d5a421bc29e', 'ding', 'SA', 'SA',
    'XCSA', 'XCSA', 20, false, true, 'DingConnect (`XCSA`) • SKU: `XCSASA72721` (20 SAR) • Cost: 2.68 OMR ($6.97 USD) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] STC -> dtone (Code: 3221, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'da1c57b4-5276-4814-ade4-1d5a421bc29e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'da1c57b4-5276-4814-ade4-1d5a421bc29e', 'dtone', 'SAU', 'SAU',
    '3221', '3221', 30, false, true, 'DT One (`3221`) • SKU: `59797` (20 SAR PIN) • Cost: 2.532 OMR ($6.58 USD) • Delivery: PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] STC -> reloadly (Code: 1124, Priority: 10, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'da1c57b4-5276-4814-ade4-1d5a421bc29e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'da1c57b4-5276-4814-ade4-1d5a421bc29e', 'reloadly', 'SA', 'SA',
    '1124', '1124', 10, false, false, 'Reloadly (`1124`) *(Disabled: +18% higher price)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Mobily -> ding (Code: MLSA, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'efc1729e-3fbb-43c1-8297-37754732aeed' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'efc1729e-3fbb-43c1-8297-37754732aeed', 'ding', 'SA', 'SA',
    'MLSA', 'MLSA', 10, true, true, 'DingConnect (`MLSA`) • SKU: `MLSASA26818` (20 SAR) • Cost: 2.68 OMR ($6.97 USD) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Mobily -> dtone (Code: 3220, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'efc1729e-3fbb-43c1-8297-37754732aeed' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'efc1729e-3fbb-43c1-8297-37754732aeed', 'dtone', 'SAU', 'SAU',
    '3220', '3220', 20, false, true, 'DT One (`3220`) • SKU: `22062` (20 SAR PIN) • Cost: 2.523 OMR ($6.56 USD) • Delivery: PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Mobily -> reloadly (Code: 424, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'efc1729e-3fbb-43c1-8297-37754732aeed' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'efc1729e-3fbb-43c1-8297-37754732aeed', 'reloadly', 'SA', 'SA',
    '424', '424', 30, false, true, 'Reloadly (`424`) • SKU: `rl_424_6.15` (20 SAR PIN) • Cost: $6.15 USD • Delivery: PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Mobily -> zendit (Code: Mobily, Priority: 10, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'efc1729e-3fbb-43c1-8297-37754732aeed' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'efc1729e-3fbb-43c1-8297-37754732aeed', 'zendit', 'SA', 'SA',
    'Mobily', 'Mobily', 10, false, false, 'Zendit (`Mobily`) *(Disabled: 0 offers in SA)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Zain KSA -> ding (Code: ZKSA, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'a03cee64-eea7-4ec7-a234-dc8a625a354e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'a03cee64-eea7-4ec7-a234-dc8a625a354e', 'ding', 'SA', 'SA',
    'ZKSA', 'ZKSA', 10, true, true, 'DingConnect (`ZKSA`) • SKU: `ZKSASA19562` (34.5 SAR) • Cost: 4.60 OMR ($11.96 USD) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Zain KSA -> dtone (Code: 3213, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'a03cee64-eea7-4ec7-a234-dc8a625a354e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'a03cee64-eea7-4ec7-a234-dc8a625a354e', 'dtone', 'SAU', 'SAU',
    '3213', '3213', 20, false, true, 'DT One (`3213`) • SKU: `32392` (184 SAR Plan) • Cost: 22.927 OMR ($59.63 USD) • Delivery: PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Zain KSA -> reloadly (Code: 426, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'a03cee64-eea7-4ec7-a234-dc8a625a354e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'a03cee64-eea7-4ec7-a234-dc8a625a354e', 'reloadly', 'SA', 'SA',
    '426', '426', 30, false, true, 'Reloadly (`426`) • SKU: `rl_426_6.10` (20 SAR PIN) • Cost: $6.10 USD • Delivery: PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Zain KSA -> zendit (Code: Zain, Priority: 10, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'a03cee64-eea7-4ec7-a234-dc8a625a354e' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'a03cee64-eea7-4ec7-a234-dc8a625a354e', 'zendit', 'SA', 'SA',
    'Zain', 'Zain', 10, false, false, 'Zendit (`Zain`) *(Disabled: 0 offers in SA)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Virgin Mobile KSA -> ding (Code: VRSA, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ec524833-a098-4ca9-b9a4-e361cb8ecf92' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ec524833-a098-4ca9-b9a4-e361cb8ecf92', 'ding', 'SA', 'SA',
    'VRSA', 'VRSA', 10, true, true, 'DingConnect (`VRSA`) • SKU: `VRSASA3546` (15 SAR) • Cost: 1.98 OMR ($5.15 USD) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Virgin Mobile KSA -> dtone (Code: 2086, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ec524833-a098-4ca9-b9a4-e361cb8ecf92' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ec524833-a098-4ca9-b9a4-e361cb8ecf92', 'dtone', 'SAU', 'SAU',
    '2086', '2086', 20, false, true, 'DT One (`2086`) • SKU: `14520` (20 SAR PIN) • Cost: 2.499 OMR ($6.50 USD) • Delivery: PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Virgin Mobile KSA -> reloadly (Code: 427, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ec524833-a098-4ca9-b9a4-e361cb8ecf92' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ec524833-a098-4ca9-b9a4-e361cb8ecf92', 'reloadly', 'SA', 'SA',
    '427', '427', 30, false, true, 'Reloadly (`427`) • SKU: `rl_427_4.55` (15 SAR PIN) • Cost: $4.55 USD • Delivery: PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Virgin Mobile KSA -> zendit (Code: Virgin Mobile, Priority: 10, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ec524833-a098-4ca9-b9a4-e361cb8ecf92' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ec524833-a098-4ca9-b9a4-e361cb8ecf92', 'zendit', 'SA', 'SA',
    'Virgin Mobile', 'Virgin Mobile', 10, false, false, 'Zendit (`Virgin Mobile`) *(Disabled: 0 offers in SA)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Lebara KSA -> ding (Code: ESSA, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '781ff056-c52f-4e96-a678-718ac1c6b647' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '781ff056-c52f-4e96-a678-718ac1c6b647', 'ding', 'SA', 'SA',
    'ESSA', 'ESSA', 10, true, true, 'DingConnect (`ESSA`) • SKU: `ESSA76375` (23 SAR) • Cost: 3.07 OMR ($7.98 USD) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Lebara KSA -> dtone (Code: 2085, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '781ff056-c52f-4e96-a678-718ac1c6b647' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '781ff056-c52f-4e96-a678-718ac1c6b647', 'dtone', 'SAU', 'SAU',
    '2085', '2085', 20, false, true, 'DT One (`2085`) • SKU: `53582` (23 SAR PIN) • Cost: 2.867 OMR ($7.46 USD) • Delivery: PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Lebara KSA -> reloadly (Code: Lebara, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '781ff056-c52f-4e96-a678-718ac1c6b647' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '781ff056-c52f-4e96-a678-718ac1c6b647', 'reloadly', 'SA', 'SA',
    'Lebara', 'Lebara', 40, false, false, '🔴 Disabled', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Lebara KSA -> zendit (Code: Lebara, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '781ff056-c52f-4e96-a678-718ac1c6b647' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '781ff056-c52f-4e96-a678-718ac1c6b647', 'zendit', 'SA', 'SA',
    'Lebara', 'Lebara', 40, false, false, '🔴 Disabled', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Friendi KSA -> ding (Code: FRSA, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8588a637-a0c9-41f7-a4fd-9fe4197f6171' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8588a637-a0c9-41f7-a4fd-9fe4197f6171', 'ding', 'SA', 'SA',
    'FRSA', 'FRSA', 10, true, true, 'DingConnect (`FRSA`) • SKU: `FRSASA79607` (15 SAR) • Cost: 1.98 OMR ($5.15 USD) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Friendi KSA -> dtone (Code: 2084, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8588a637-a0c9-41f7-a4fd-9fe4197f6171' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8588a637-a0c9-41f7-a4fd-9fe4197f6171', 'dtone', 'SAU', 'SAU',
    '2084', '2084', 20, false, true, 'DT One (`2084`) • SKU: `14516` (20 SAR PIN) • Cost: 2.496 OMR ($6.49 USD) • Delivery: PIN Voucher', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Friendi KSA -> reloadly (Code: Friendi, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8588a637-a0c9-41f7-a4fd-9fe4197f6171' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8588a637-a0c9-41f7-a4fd-9fe4197f6171', 'reloadly', 'SA', 'SA',
    'Friendi', 'Friendi', 40, false, false, '🔴 Disabled', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Friendi KSA -> zendit (Code: Friendi, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8588a637-a0c9-41f7-a4fd-9fe4197f6171' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8588a637-a0c9-41f7-a4fd-9fe4197f6171', 'zendit', 'SA', 'SA',
    'Friendi', 'Friendi', 40, false, false, '🔴 Disabled', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Salam Mobile KSA -> ding (Code: UQSA, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'fab6caff-713a-4338-a14c-872c1a17cc3e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'fab6caff-713a-4338-a14c-872c1a17cc3e', 'ding', 'SA', 'SA',
    'UQSA', 'UQSA', 10, true, true, '🟢 Exclusive Primary (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Salam Mobile KSA -> reloadly (Code: Salam, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'fab6caff-713a-4338-a14c-872c1a17cc3e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'fab6caff-713a-4338-a14c-872c1a17cc3e', 'reloadly', 'SA', 'SA',
    'Salam', 'Salam', 40, false, false, '🔴 Disabled', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Salam Mobile KSA -> dtone (Code: Salam, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'fab6caff-713a-4338-a14c-872c1a17cc3e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'fab6caff-713a-4338-a14c-872c1a17cc3e', 'dtone', 'SAU', 'SAU',
    'Salam', 'Salam', 40, false, false, '🔴 Disabled', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Salam Mobile KSA -> zendit (Code: Salam, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'fab6caff-713a-4338-a14c-872c1a17cc3e' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'fab6caff-713a-4338-a14c-872c1a17cc3e', 'zendit', 'SA', 'SA',
    'Salam', 'Salam', 40, false, false, '🔴 Disabled', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Turkcell -> reloadly (Code: 509, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'fe1eb878-c1d2-4a01-8510-7f938c73712e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'fe1eb878-c1d2-4a01-8510-7f938c73712e', 'reloadly', 'TR', 'TR',
    '509', '509', 10, true, true, 'Reloadly (`509` / `1177`) • Denom: 65 TRY ($1.82 USD) • Cost: $1.765 USD net • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Turkcell -> dtone (Code: 679, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'fe1eb878-c1d2-4a01-8510-7f938c73712e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'fe1eb878-c1d2-4a01-8510-7f938c73712e', 'dtone', 'TUR', 'TUR',
    '679', '679', 20, false, true, 'DT One (`679`) • Denom: 200 TRY (`67167`) • Cost: 2.047 OMR ($5.32 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Turkcell -> zendit (Code: Turkcell, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'fe1eb878-c1d2-4a01-8510-7f938c73712e' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'fe1eb878-c1d2-4a01-8510-7f938c73712e', 'zendit', 'TR', 'TR',
    'Turkcell', 'Turkcell', 30, false, true, 'Zendit (`Turkcell`) • Offer: `TURKCELL_TR_10-I` • Cost: $10.00 USD (200 TRY) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Turkcell -> ding (Code: TZTR, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'fe1eb878-c1d2-4a01-8510-7f938c73712e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'fe1eb878-c1d2-4a01-8510-7f938c73712e', 'ding', 'TR', 'TR',
    'TZTR', 'TZTR', 40, false, false, 'DingConnect (`TZTR`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Vodafone Turkey -> reloadly (Code: 1178, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8c132d25-bcd4-4764-83ee-15f63924f665' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8c132d25-bcd4-4764-83ee-15f63924f665', 'reloadly', 'TR', 'TR',
    '1178', '1178', 10, true, true, 'Reloadly (`1178` / `512`) • Denom: 90 TRY ($2.52 USD) • Cost: $2.444 USD net • Delivery: Direct Bundle', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Vodafone Turkey -> zendit (Code: Vodafone, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8c132d25-bcd4-4764-83ee-15f63924f665' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8c132d25-bcd4-4764-83ee-15f63924f665', 'zendit', 'TR', 'TR',
    'Vodafone', 'Vodafone', 20, false, true, 'Zendit (`Vodafone`) • Offer: `VODAFONE_TR_001` • Cost: $5.00 USD (100 TRY) • Delivery: Direct Top-Up', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Vodafone Turkey -> dtone (Code: 662, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8c132d25-bcd4-4764-83ee-15f63924f665' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8c132d25-bcd4-4764-83ee-15f63924f665', 'dtone', 'TUR', 'TUR',
    '662', '662', 30, false, true, 'DT One (`662`) • Denom: 250 TRY (`50568`) • Cost: 2.558 OMR ($6.65 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Vodafone Turkey -> ding (Code: VFTR, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8c132d25-bcd4-4764-83ee-15f63924f665' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8c132d25-bcd4-4764-83ee-15f63924f665', 'ding', 'TR', 'TR',
    'VFTR', 'VFTR', 40, false, false, 'DingConnect (`VFTR`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Bimcell -> dtone (Code: 46, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '181f1aa0-41a6-4221-baa2-f62b63a1b64e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '181f1aa0-41a6-4221-baa2-f62b63a1b64e', 'dtone', 'TUR', 'TUR',
    '46', '46', 10, true, true, 'DT One (`46`) • Via Türk Telekom Rails (300 TRY) • Cost: 3.071 OMR ($7.98 USD) • Delivery: Direct via TT', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Bimcell -> reloadly (Code: 510, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '181f1aa0-41a6-4221-baa2-f62b63a1b64e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '181f1aa0-41a6-4221-baa2-f62b63a1b64e', 'reloadly', 'TR', 'TR',
    '510', '510', 20, false, true, 'Reloadly (`510`) • Via Türk Telekom Rails • Cost: $8.157 USD net • Delivery: Direct via TT', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Bimcell -> zendit (Code: TurkTelekom, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '181f1aa0-41a6-4221-baa2-f62b63a1b64e' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '181f1aa0-41a6-4221-baa2-f62b63a1b64e', 'zendit', 'TR', 'TR',
    'TurkTelekom', 'TurkTelekom', 30, false, true, 'Zendit (`TurkTelekom`) • Via Türk Telekom Rails • Cost: $15.00 USD (300 TRY) • Delivery: Direct via TT', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Bimcell -> ding (Code: AVTR, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '181f1aa0-41a6-4221-baa2-f62b63a1b64e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '181f1aa0-41a6-4221-baa2-f62b63a1b64e', 'ding', 'TR', 'TR',
    'AVTR', 'AVTR', 40, false, false, 'DingConnect (`AVTR`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Pttcell -> dtone (Code: 46, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3e9caec3-6125-4aa8-b01f-512a3fe88c18' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3e9caec3-6125-4aa8-b01f-512a3fe88c18', 'dtone', 'TUR', 'TUR',
    '46', '46', 10, true, true, 'DT One (`46`) • Via Türk Telekom Rails (300 TRY) • Cost: 3.071 OMR ($7.98 USD) • Delivery: Direct via TT', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Pttcell -> reloadly (Code: 510, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3e9caec3-6125-4aa8-b01f-512a3fe88c18' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3e9caec3-6125-4aa8-b01f-512a3fe88c18', 'reloadly', 'TR', 'TR',
    '510', '510', 20, false, true, 'Reloadly (`510`) • Via Türk Telekom Rails • Cost: $8.157 USD net • Delivery: Direct via TT', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Pttcell -> zendit (Code: TurkTelekom, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3e9caec3-6125-4aa8-b01f-512a3fe88c18' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3e9caec3-6125-4aa8-b01f-512a3fe88c18', 'zendit', 'TR', 'TR',
    'TurkTelekom', 'TurkTelekom', 30, false, true, 'Zendit (`TurkTelekom`) • Via Türk Telekom Rails • Cost: $15.00 USD (300 TRY) • Delivery: Direct via TT', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Pttcell -> ding (Code: AVTR, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3e9caec3-6125-4aa8-b01f-512a3fe88c18' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3e9caec3-6125-4aa8-b01f-512a3fe88c18', 'ding', 'TR', 'TR',
    'AVTR', 'AVTR', 40, false, false, 'DingConnect (`AVTR`) *(Disabled: 0 UAT offers)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Vodafone Cyprus -> dtone (Code: 1931, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f7c51a5c-4bb2-4005-9152-4baca61018bf' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f7c51a5c-4bb2-4005-9152-4baca61018bf', 'dtone', 'TUR', 'TUR',
    '1931', '1931', 10, true, true, 'DT One (`1931`) • Denom: 12 TRY (`11581`) • Cost: 0.121 OMR ($0.31 USD) • Delivery: Direct Recharge', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Vodafone Cyprus -> reloadly (Code: 511, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f7c51a5c-4bb2-4005-9152-4baca61018bf' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f7c51a5c-4bb2-4005-9152-4baca61018bf', 'reloadly', 'TR', 'TR',
    '511', '511', 20, false, false, 'Reloadly (`511`) *(Disabled: 0 Sandbox Denoms)*', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Vodafone Cyprus -> zendit (Code: Vodafone, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f7c51a5c-4bb2-4005-9152-4baca61018bf' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f7c51a5c-4bb2-4005-9152-4baca61018bf', 'zendit', 'TR', 'TR',
    'Vodafone', 'Vodafone', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Vodafone Cyprus -> ding (Code: Unsupported, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f7c51a5c-4bb2-4005-9152-4baca61018bf' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f7c51a5c-4bb2-4005-9152-4baca61018bf', 'ding', 'TR', 'TR',
    'Unsupported', 'Unsupported', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TN] Ooredoo Tunisia -> dtone (Code: 1532, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '27a7a925-1af0-4697-b39e-f0a12a8c131b' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '27a7a925-1af0-4697-b39e-f0a12a8c131b', 'dtone', 'TUN', 'TUN',
    '1532', '1532', 10, true, true, '🟢 Primary Direct Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TN] Ooredoo Tunisia -> reloadly (Code: 508, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '27a7a925-1af0-4697-b39e-f0a12a8c131b' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '27a7a925-1af0-4697-b39e-f0a12a8c131b', 'reloadly', 'TN', 'TN',
    '508', '508', 20, false, true, 'Reloadly (`508`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TN] Ooredoo Tunisia -> zendit (Code: Ooredoo, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '27a7a925-1af0-4697-b39e-f0a12a8c131b' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '27a7a925-1af0-4697-b39e-f0a12a8c131b', 'zendit', 'TN', 'TN',
    'Ooredoo', 'Ooredoo', 30, false, true, 'Zendit (`Ooredoo`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TN] Ooredoo Tunisia -> ding (Code: TUTN, Priority: 10, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '27a7a925-1af0-4697-b39e-f0a12a8c131b' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '27a7a925-1af0-4697-b39e-f0a12a8c131b', 'ding', 'TN', 'TN',
    'TUTN', 'TUTN', 10, false, false, 'DingConnect (`TUTN`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TN] Tunisie Telecom -> dtone (Code: 678, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2ae782fb-66db-4471-b773-bfee4a5d7707' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2ae782fb-66db-4471-b773-bfee4a5d7707', 'dtone', 'TUN', 'TUN',
    '678', '678', 10, true, true, '🟢 Primary Direct Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TN] Tunisie Telecom -> reloadly (Code: 507, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2ae782fb-66db-4471-b773-bfee4a5d7707' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2ae782fb-66db-4471-b773-bfee4a5d7707', 'reloadly', 'TN', 'TN',
    '507', '507', 20, false, true, 'Reloadly (`507`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TN] Tunisie Telecom -> zendit (Code: TunisieTelecom, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2ae782fb-66db-4471-b773-bfee4a5d7707' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2ae782fb-66db-4471-b773-bfee4a5d7707', 'zendit', 'TN', 'TN',
    'TunisieTelecom', 'TunisieTelecom', 30, false, true, 'Zendit (`TunisieTelecom`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TN] Tunisie Telecom -> ding (Code: TWTN, Priority: 10, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2ae782fb-66db-4471-b773-bfee4a5d7707' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2ae782fb-66db-4471-b773-bfee4a5d7707', 'ding', 'TN', 'TN',
    'TWTN', 'TWTN', 10, false, false, 'DingConnect (`TWTN`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TN] Orange Tunisia -> dtone (Code: 1530, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e6f8679a-7232-4981-9e39-abcae5009f6f' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e6f8679a-7232-4981-9e39-abcae5009f6f', 'dtone', 'TUN', 'TUN',
    '1530', '1530', 10, true, true, '🟢 Primary Direct Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TN] Orange Tunisia -> reloadly (Code: 506, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e6f8679a-7232-4981-9e39-abcae5009f6f' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e6f8679a-7232-4981-9e39-abcae5009f6f', 'reloadly', 'TN', 'TN',
    '506', '506', 20, false, true, 'Reloadly (`506`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TN] Orange Tunisia -> zendit (Code: Orange, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e6f8679a-7232-4981-9e39-abcae5009f6f' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e6f8679a-7232-4981-9e39-abcae5009f6f', 'zendit', 'TN', 'TN',
    'Orange', 'Orange', 30, false, true, 'Zendit (`Orange`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TN] Orange Tunisia -> ding (Code: ORTN, Priority: 10, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e6f8679a-7232-4981-9e39-abcae5009f6f' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e6f8679a-7232-4981-9e39-abcae5009f6f', 'ding', 'TN', 'TN',
    'ORTN', 'ORTN', 10, false, false, 'DingConnect (`ORTN`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Etisalat (e&) -> reloadly (Code: 1100, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '28905875-2684-40a3-bdb5-8aef0497ea99' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '28905875-2684-40a3-bdb5-8aef0497ea99', 'reloadly', 'AE', 'AE',
    '1100', '1100', 10, true, true, '🟢 Primary Direct (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Etisalat (e&) -> zendit (Code: Etisalat, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '28905875-2684-40a3-bdb5-8aef0497ea99' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '28905875-2684-40a3-bdb5-8aef0497ea99', 'zendit', 'AE', 'AE',
    'Etisalat', 'Etisalat', 20, false, true, '🟢 Secondary Direct (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Etisalat (e&) -> dtone (Code: 2097, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '28905875-2684-40a3-bdb5-8aef0497ea99' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '28905875-2684-40a3-bdb5-8aef0497ea99', 'dtone', 'ARE', 'ARE',
    '2097', '2097', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Etisalat (e&) -> ding (Code: ETAE, Priority: 40, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '28905875-2684-40a3-bdb5-8aef0497ea99' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '28905875-2684-40a3-bdb5-8aef0497ea99', 'ding', 'AE', 'AE',
    'ETAE', 'ETAE', 40, false, true, '🟢 Quaternary Route (`priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Virgin Mobile UAE -> reloadly (Code: 1155, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '821f233d-272c-4631-a3d2-e831ddf650c4' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '821f233d-272c-4631-a3d2-e831ddf650c4', 'reloadly', 'AE', 'AE',
    '1155', '1155', 10, true, true, '🟢 Primary PIN Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Virgin Mobile UAE -> dtone (Code: 3392, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '821f233d-272c-4631-a3d2-e831ddf650c4' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '821f233d-272c-4631-a3d2-e831ddf650c4', 'dtone', 'ARE', 'ARE',
    '3392', '3392', 20, false, true, '🟢 Secondary PIN Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Virgin Mobile UAE -> ding (Code: VMAE, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '821f233d-272c-4631-a3d2-e831ddf650c4' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '821f233d-272c-4631-a3d2-e831ddf650c4', 'ding', 'AE', 'AE',
    'VMAE', 'VMAE', 30, false, true, '🟢 Tertiary PIN Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [AE] Virgin Mobile UAE -> zendit (Code: Virgin Mobile, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '821f233d-272c-4631-a3d2-e831ddf650c4' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '821f233d-272c-4631-a3d2-e831ddf650c4', 'zendit', 'AE', 'AE',
    'Virgin Mobile', 'Virgin Mobile', 40, false, false, '🔴 Disabled (`is_enabled: false`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Banglalink -> dtone (Code: 1447, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b9cbc241-3650-41ab-b8c3-3c9612333dfb' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b9cbc241-3650-41ab-b8c3-3c9612333dfb', 'dtone', 'BGD', 'BGD',
    '1447', '1447', 10, true, true, '🟢 Primary Direct Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Banglalink -> zendit (Code: Banglalink, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b9cbc241-3650-41ab-b8c3-3c9612333dfb' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b9cbc241-3650-41ab-b8c3-3c9612333dfb', 'zendit', 'BD', 'BD',
    'Banglalink', 'Banglalink', 20, false, true, '🟢 Secondary Direct Route (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Banglalink -> reloadly (Code: 24, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b9cbc241-3650-41ab-b8c3-3c9612333dfb' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b9cbc241-3650-41ab-b8c3-3c9612333dfb', 'reloadly', 'BD', 'BD',
    '24', '24', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Banglalink -> ding (Code: BGBD, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b9cbc241-3650-41ab-b8c3-3c9612333dfb' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b9cbc241-3650-41ab-b8c3-3c9612333dfb', 'ding', 'BD', 'BD',
    'BGBD', 'BGBD', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Grameenphone -> dtone (Code: 249, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '26dacbcd-1733-4a9c-b468-3589a88597bf' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '26dacbcd-1733-4a9c-b468-3589a88597bf', 'dtone', 'BGD', 'BGD',
    '249', '249', 10, true, true, '🟢 Primary Direct Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Grameenphone -> reloadly (Code: 26, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '26dacbcd-1733-4a9c-b468-3589a88597bf' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '26dacbcd-1733-4a9c-b468-3589a88597bf', 'reloadly', 'BD', 'BD',
    '26', '26', 20, false, true, '🟢 Secondary Direct Route (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Grameenphone -> zendit (Code: GrameenPhone, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '26dacbcd-1733-4a9c-b468-3589a88597bf' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '26dacbcd-1733-4a9c-b468-3589a88597bf', 'zendit', 'BD', 'BD',
    'GrameenPhone', 'GrameenPhone', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Grameenphone -> ding (Code: GEBD, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '26dacbcd-1733-4a9c-b468-3589a88597bf' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '26dacbcd-1733-4a9c-b468-3589a88597bf', 'ding', 'BD', 'BD',
    'GEBD', 'GEBD', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Robi Axiata -> dtone (Code: 1446, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'caafbd48-6451-44d1-9eb0-987af41e7739' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'caafbd48-6451-44d1-9eb0-987af41e7739', 'dtone', 'BGD', 'BGD',
    '1446', '1446', 10, true, true, '🟢 Primary Direct Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Robi Axiata -> reloadly (Code: 25, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'caafbd48-6451-44d1-9eb0-987af41e7739' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'caafbd48-6451-44d1-9eb0-987af41e7739', 'reloadly', 'BD', 'BD',
    '25', '25', 20, false, true, '🟢 Secondary Direct Route (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Robi Axiata -> zendit (Code: Robi, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'caafbd48-6451-44d1-9eb0-987af41e7739' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'caafbd48-6451-44d1-9eb0-987af41e7739', 'zendit', 'BD', 'BD',
    'Robi', 'Robi', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [BD] Robi Axiata -> ding (Code: RLBD, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'caafbd48-6451-44d1-9eb0-987af41e7739' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'caafbd48-6451-44d1-9eb0-987af41e7739', 'ding', 'BD', 'BD',
    'RLBD', 'RLBD', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] 1&1 Telecom -> dtone (Code: Unsupported in Aggregators, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ef7b1cb4-9c87-433f-bb63-39250884f2f2' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ef7b1cb4-9c87-433f-bb63-39250884f2f2', 'dtone', 'DEU', 'DEU',
    'Unsupported in Aggregators', 'Unsupported in Aggregators', 40, false, false, '🔴 Disabled in Aggregators', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] 1&1 Telecom -> reloadly (Code: Unsupported in Aggregators, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ef7b1cb4-9c87-433f-bb63-39250884f2f2' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ef7b1cb4-9c87-433f-bb63-39250884f2f2', 'reloadly', 'DE', 'DE',
    'Unsupported in Aggregators', 'Unsupported in Aggregators', 40, false, false, '🔴 Disabled in Aggregators', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] 1&1 Telecom -> zendit (Code: Unsupported in Aggregators, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ef7b1cb4-9c87-433f-bb63-39250884f2f2' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ef7b1cb4-9c87-433f-bb63-39250884f2f2', 'zendit', 'DE', 'DE',
    'Unsupported in Aggregators', 'Unsupported in Aggregators', 40, false, false, '🔴 Disabled in Aggregators', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] 1&1 Telecom -> ding (Code: Unsupported in Aggregators, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ef7b1cb4-9c87-433f-bb63-39250884f2f2' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ef7b1cb4-9c87-433f-bb63-39250884f2f2', 'ding', 'DE', 'DE',
    'Unsupported in Aggregators', 'Unsupported in Aggregators', 40, false, false, '🔴 Disabled in Aggregators', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ay Yildiz -> zendit (Code: AyYildiz, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '51547096-c721-4d93-8bfc-489780c5fe4a' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '51547096-c721-4d93-8bfc-489780c5fe4a', 'zendit', 'DE', 'DE',
    'AyYildiz', 'AyYildiz', 10, true, true, '🟢 Primary Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ay Yildiz -> dtone (Code: 2135, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '51547096-c721-4d93-8bfc-489780c5fe4a' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '51547096-c721-4d93-8bfc-489780c5fe4a', 'dtone', 'DEU', 'DEU',
    '2135', '2135', 20, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ay Yildiz -> ding (Code: AYDE, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '51547096-c721-4d93-8bfc-489780c5fe4a' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '51547096-c721-4d93-8bfc-489780c5fe4a', 'ding', 'DE', 'DE',
    'AYDE', 'AYDE', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ay Yildiz -> reloadly (Code: Ay Yildiz, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '51547096-c721-4d93-8bfc-489780c5fe4a' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '51547096-c721-4d93-8bfc-489780c5fe4a', 'reloadly', 'DE', 'DE',
    'Ay Yildiz', 'Ay Yildiz', 40, false, false, '🔴 Disabled (`is_enabled: false`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] BILDmobil -> reloadly (Code: 848, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '55100b54-dc63-4838-bba0-44fea2bae915' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '55100b54-dc63-4838-bba0-44fea2bae915', 'reloadly', 'DE', 'DE',
    '848', '848', 10, true, true, '🟢 Primary Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] BILDmobil -> dtone (Code: 3111, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '55100b54-dc63-4838-bba0-44fea2bae915' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '55100b54-dc63-4838-bba0-44fea2bae915', 'dtone', 'DEU', 'DEU',
    '3111', '3111', 20, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] BILDmobil -> ding (Code: B6DE, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '55100b54-dc63-4838-bba0-44fea2bae915' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '55100b54-dc63-4838-bba0-44fea2bae915', 'ding', 'DE', 'DE',
    'B6DE', 'B6DE', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] BILDmobil -> zendit (Code: Unsupported, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '55100b54-dc63-4838-bba0-44fea2bae915' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '55100b54-dc63-4838-bba0-44fea2bae915', 'zendit', 'DE', 'DE',
    'Unsupported', 'Unsupported', 40, false, false, '🔴 Disabled (`is_enabled: false`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Blau -> reloadly (Code: 849, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7b5c7719-b34b-4c51-a2c6-b486c6b90e67' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7b5c7719-b34b-4c51-a2c6-b486c6b90e67', 'reloadly', 'DE', 'DE',
    '849', '849', 10, true, true, '🟢 Primary Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Blau -> zendit (Code: Blau, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7b5c7719-b34b-4c51-a2c6-b486c6b90e67' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7b5c7719-b34b-4c51-a2c6-b486c6b90e67', 'zendit', 'DE', 'DE',
    'Blau', 'Blau', 20, false, true, '🟢 Secondary Direct Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Blau -> dtone (Code: 2754, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7b5c7719-b34b-4c51-a2c6-b486c6b90e67' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7b5c7719-b34b-4c51-a2c6-b486c6b90e67', 'dtone', 'DEU', 'DEU',
    '2754', '2754', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Blau -> ding (Code: BSDE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7b5c7719-b34b-4c51-a2c6-b486c6b90e67' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7b5c7719-b34b-4c51-a2c6-b486c6b90e67', 'ding', 'DE', 'DE',
    'BSDE', 'BSDE', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Congstar -> reloadly (Code: 850, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7f12a660-ab11-47a2-bf13-6cd7a86bb51b' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7f12a660-ab11-47a2-bf13-6cd7a86bb51b', 'reloadly', 'DE', 'DE',
    '850', '850', 10, true, true, '🟢 Primary Micro-Refill Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Congstar -> zendit (Code: Congstar, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7f12a660-ab11-47a2-bf13-6cd7a86bb51b' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7f12a660-ab11-47a2-bf13-6cd7a86bb51b', 'zendit', 'DE', 'DE',
    'Congstar', 'Congstar', 20, false, true, '🟢 Secondary Direct Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Congstar -> dtone (Code: 2139, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7f12a660-ab11-47a2-bf13-6cd7a86bb51b' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7f12a660-ab11-47a2-bf13-6cd7a86bb51b', 'dtone', 'DEU', 'DEU',
    '2139', '2139', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Congstar -> ding (Code: C4DE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7f12a660-ab11-47a2-bf13-6cd7a86bb51b' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7f12a660-ab11-47a2-bf13-6cd7a86bb51b', 'ding', 'DE', 'DE',
    'C4DE', 'C4DE', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Fonic -> reloadly (Code: 853, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '70754905-9221-4142-a400-b68f51bdd78e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '70754905-9221-4142-a400-b68f51bdd78e', 'reloadly', 'DE', 'DE',
    '853', '853', 10, true, true, '🟢 Primary Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Fonic -> dtone (Code: 2768, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '70754905-9221-4142-a400-b68f51bdd78e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '70754905-9221-4142-a400-b68f51bdd78e', 'dtone', 'DEU', 'DEU',
    '2768', '2768', 20, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Fonic -> ding (Code: F1DE, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '70754905-9221-4142-a400-b68f51bdd78e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '70754905-9221-4142-a400-b68f51bdd78e', 'ding', 'DE', 'DE',
    'F1DE', 'F1DE', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Fonic -> zendit (Code: Fonic, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '70754905-9221-4142-a400-b68f51bdd78e' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '70754905-9221-4142-a400-b68f51bdd78e', 'zendit', 'DE', 'DE',
    'Fonic', 'Fonic', 40, false, false, '🔴 Disabled (`is_enabled: false`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Klarmobil -> reloadly (Code: 854, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '88e44ab2-2e75-4159-8695-e35937f70b7d' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '88e44ab2-2e75-4159-8695-e35937f70b7d', 'reloadly', 'DE', 'DE',
    '854', '854', 10, true, true, '🟢 Primary Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Klarmobil -> dtone (Code: 3117, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '88e44ab2-2e75-4159-8695-e35937f70b7d' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '88e44ab2-2e75-4159-8695-e35937f70b7d', 'dtone', 'DEU', 'DEU',
    '3117', '3117', 20, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Klarmobil -> zendit (Code: Unsupported, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '88e44ab2-2e75-4159-8695-e35937f70b7d' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '88e44ab2-2e75-4159-8695-e35937f70b7d', 'zendit', 'DE', 'DE',
    'Unsupported', 'Unsupported', 40, false, false, '🔴 Disabled (`is_enabled: false`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Klarmobil -> ding (Code: Unsupported, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '88e44ab2-2e75-4159-8695-e35937f70b7d' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '88e44ab2-2e75-4159-8695-e35937f70b7d', 'ding', 'DE', 'DE',
    'Unsupported', 'Unsupported', 40, false, false, '🔴 Disabled (`is_enabled: false`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ortel Mobile -> reloadly (Code: 665, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2652fd9d-22d8-4935-8aab-c84bcfe38026' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2652fd9d-22d8-4935-8aab-c84bcfe38026', 'reloadly', 'DE', 'DE',
    '665', '665', 10, true, true, '🟢 Primary Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ortel Mobile -> zendit (Code: Ortel, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2652fd9d-22d8-4935-8aab-c84bcfe38026' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2652fd9d-22d8-4935-8aab-c84bcfe38026', 'zendit', 'DE', 'DE',
    'Ortel', 'Ortel', 20, false, true, '🟢 Secondary Direct Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ortel Mobile -> dtone (Code: 2146, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2652fd9d-22d8-4935-8aab-c84bcfe38026' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2652fd9d-22d8-4935-8aab-c84bcfe38026', 'dtone', 'DEU', 'DEU',
    '2146', '2146', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Ortel Mobile -> ding (Code: OTDE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '2652fd9d-22d8-4935-8aab-c84bcfe38026' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '2652fd9d-22d8-4935-8aab-c84bcfe38026', 'ding', 'DE', 'DE',
    'OTDE', 'OTDE', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Otelo -> reloadly (Code: 867, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '94231364-38c7-4bdf-9327-0d95c4a7a1af' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '94231364-38c7-4bdf-9327-0d95c4a7a1af', 'reloadly', 'DE', 'DE',
    '867', '867', 10, true, true, '🟢 Primary Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Otelo -> zendit (Code: OTELO, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '94231364-38c7-4bdf-9327-0d95c4a7a1af' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '94231364-38c7-4bdf-9327-0d95c4a7a1af', 'zendit', 'DE', 'DE',
    'OTELO', 'OTELO', 20, false, true, '🟢 Secondary Direct Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Otelo -> dtone (Code: 2148, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '94231364-38c7-4bdf-9327-0d95c4a7a1af' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '94231364-38c7-4bdf-9327-0d95c4a7a1af', 'dtone', 'DEU', 'DEU',
    '2148', '2148', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Otelo -> ding (Code: OEDE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '94231364-38c7-4bdf-9327-0d95c4a7a1af' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '94231364-38c7-4bdf-9327-0d95c4a7a1af', 'ding', 'DE', 'DE',
    'OEDE', 'OEDE', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Tchibo Mobil -> reloadly (Code: 872, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'cc280785-dcd2-4f7c-9855-c8eba807808e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'cc280785-dcd2-4f7c-9855-c8eba807808e', 'reloadly', 'DE', 'DE',
    '872', '872', 10, true, true, '🟢 Primary Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Tchibo Mobil -> ding (Code: E825B8DE, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'cc280785-dcd2-4f7c-9855-c8eba807808e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'cc280785-dcd2-4f7c-9855-c8eba807808e', 'ding', 'DE', 'DE',
    'E825B8DE', 'E825B8DE', 20, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Tchibo Mobil -> dtone (Code: Unsupported, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'cc280785-dcd2-4f7c-9855-c8eba807808e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'cc280785-dcd2-4f7c-9855-c8eba807808e', 'dtone', 'DEU', 'DEU',
    'Unsupported', 'Unsupported', 40, false, false, '🔴 Disabled (`is_enabled: false`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Tchibo Mobil -> zendit (Code: Unsupported, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'cc280785-dcd2-4f7c-9855-c8eba807808e' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'cc280785-dcd2-4f7c-9855-c8eba807808e', 'zendit', 'DE', 'DE',
    'Unsupported', 'Unsupported', 40, false, false, '🔴 Disabled (`is_enabled: false`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Deutsche Telekom -> dtone (Code: 602, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f3bd840a-bc97-4ae2-8206-e27f0cf94e56' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f3bd840a-bc97-4ae2-8206-e27f0cf94e56', 'dtone', 'DEU', 'DEU',
    '602', '602', 10, true, true, '🟢 Primary Direct & PIN Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Deutsche Telekom -> reloadly (Code: 664, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f3bd840a-bc97-4ae2-8206-e27f0cf94e56' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f3bd840a-bc97-4ae2-8206-e27f0cf94e56', 'reloadly', 'DE', 'DE',
    '664', '664', 20, false, true, '🟢 Secondary PIN Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Deutsche Telekom -> zendit (Code: Telekom, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f3bd840a-bc97-4ae2-8206-e27f0cf94e56' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f3bd840a-bc97-4ae2-8206-e27f0cf94e56', 'zendit', 'DE', 'DE',
    'Telekom', 'Telekom', 30, false, true, '🟢 Tertiary Direct Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [DE] Deutsche Telekom -> ding (Code: TLDE, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f3bd840a-bc97-4ae2-8206-e27f0cf94e56' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f3bd840a-bc97-4ae2-8206-e27f0cf94e56', 'ding', 'DE', 'DE',
    'TLDE', 'TLDE', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Airtel -> dtone (Code: 1371, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd34d491a-cbc8-4a31-901b-0b2279bb73c0' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd34d491a-cbc8-4a31-901b-0b2279bb73c0', 'dtone', 'IND', 'IND',
    '1371', '1371', 10, true, true, '🟢 Primary Direct (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Airtel -> zendit (Code: Airtel, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd34d491a-cbc8-4a31-901b-0b2279bb73c0' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd34d491a-cbc8-4a31-901b-0b2279bb73c0', 'zendit', 'IN', 'IN',
    'Airtel', 'Airtel', 20, false, true, '🟢 Secondary Direct (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Airtel -> reloadly (Code: 200, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd34d491a-cbc8-4a31-901b-0b2279bb73c0' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd34d491a-cbc8-4a31-901b-0b2279bb73c0', 'reloadly', 'IN', 'IN',
    '200', '200', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Airtel -> ding (Code: AIIN, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd34d491a-cbc8-4a31-901b-0b2279bb73c0' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd34d491a-cbc8-4a31-901b-0b2279bb73c0', 'ding', 'IN', 'IN',
    'AIIN', 'AIIN', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] BSNL -> dtone (Code: 1420, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1e07e23c-b088-4ded-9a3c-fc41d3e46f97' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1e07e23c-b088-4ded-9a3c-fc41d3e46f97', 'dtone', 'IND', 'IND',
    '1420', '1420', 10, true, true, '🟢 Primary Direct (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] BSNL -> zendit (Code: BSNL, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1e07e23c-b088-4ded-9a3c-fc41d3e46f97' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1e07e23c-b088-4ded-9a3c-fc41d3e46f97', 'zendit', 'IN', 'IN',
    'BSNL', 'BSNL', 20, false, true, '🟢 Secondary Direct (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] BSNL -> reloadly (Code: 193, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1e07e23c-b088-4ded-9a3c-fc41d3e46f97' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1e07e23c-b088-4ded-9a3c-fc41d3e46f97', 'reloadly', 'IN', 'IN',
    '193', '193', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] BSNL -> ding (Code: BLIN, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1e07e23c-b088-4ded-9a3c-fc41d3e46f97' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1e07e23c-b088-4ded-9a3c-fc41d3e46f97', 'ding', 'IN', 'IN',
    'BLIN', 'BLIN', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Jio -> dtone (Code: 2808, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e', 'dtone', 'IND', 'IND',
    '2808', '2808', 10, true, true, '🟢 Primary Direct (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Jio -> zendit (Code: Jio, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e', 'zendit', 'IN', 'IN',
    'Jio', 'Jio', 20, false, true, '🟢 Secondary Direct (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Jio -> reloadly (Code: 786, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e', 'reloadly', 'IN', 'IN',
    '786', '786', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IN] Jio -> ding (Code: RJIN, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e', 'ding', 'IN', 'IN',
    'RJIN', 'RJIN', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] AsiaCell -> zendit (Code: AsiaCell, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8fcac8eb-0992-4690-8041-069d142b1c8b' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8fcac8eb-0992-4690-8041-069d142b1c8b', 'zendit', 'IQ', 'IQ',
    'AsiaCell', 'AsiaCell', 10, true, true, '🟢 Primary Direct (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] AsiaCell -> dtone (Code: 42, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8fcac8eb-0992-4690-8041-069d142b1c8b' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8fcac8eb-0992-4690-8041-069d142b1c8b', 'dtone', 'IRQ', 'IRQ',
    '42', '42', 20, false, true, '🟢 Secondary Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] AsiaCell -> reloadly (Code: 246, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8fcac8eb-0992-4690-8041-069d142b1c8b' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8fcac8eb-0992-4690-8041-069d142b1c8b', 'reloadly', 'IQ', 'IQ',
    '246', '246', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [IQ] AsiaCell -> ding (Code: ACIQ, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '8fcac8eb-0992-4690-8041-069d142b1c8b' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '8fcac8eb-0992-4690-8041-069d142b1c8b', 'ding', 'IQ', 'IQ',
    'ACIQ', 'ACIQ', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Umniah -> reloadly (Code: 1150, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'bd2761bb-020a-4fd7-857c-cc8e4292f330' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'bd2761bb-020a-4fd7-857c-cc8e4292f330', 'reloadly', 'JO', 'JO',
    '1150', '1150', 10, true, true, '🟢 Primary Direct Top-Up (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Umniah -> dtone (Code: 690, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'bd2761bb-020a-4fd7-857c-cc8e4292f330' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'bd2761bb-020a-4fd7-857c-cc8e4292f330', 'dtone', 'JOR', 'JOR',
    '690', '690', 20, false, true, '🟢 Secondary PIN Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Umniah -> zendit (Code: Umniah, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'bd2761bb-020a-4fd7-857c-cc8e4292f330' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'bd2761bb-020a-4fd7-857c-cc8e4292f330', 'zendit', 'JO', 'JO',
    'Umniah', 'Umniah', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [JO] Umniah -> ding (Code: Umniah, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'bd2761bb-020a-4fd7-857c-cc8e4292f330' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'bd2761bb-020a-4fd7-857c-cc8e4292f330', 'ding', 'JO', 'JO',
    'Umniah', 'Umniah', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Dialog Axiata -> dtone (Code: 360, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '71785c0a-4d93-4d31-a2ad-58778dfe21de' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '71785c0a-4d93-4d31-a2ad-58778dfe21de', 'dtone', 'LKA', 'LKA',
    '360', '360', 10, true, true, '🟢 Primary Direct Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Dialog Axiata -> reloadly (Code: 472, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '71785c0a-4d93-4d31-a2ad-58778dfe21de' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '71785c0a-4d93-4d31-a2ad-58778dfe21de', 'reloadly', 'LK', 'LK',
    '472', '472', 20, false, true, '🟢 Secondary Direct Route (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Dialog Axiata -> zendit (Code: Dialog, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '71785c0a-4d93-4d31-a2ad-58778dfe21de' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '71785c0a-4d93-4d31-a2ad-58778dfe21de', 'zendit', 'LK', 'LK',
    'Dialog', 'Dialog', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [LK] Dialog Axiata -> ding (Code: DGLK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '71785c0a-4d93-4d31-a2ad-58778dfe21de' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '71785c0a-4d93-4d31-a2ad-58778dfe21de', 'ding', 'LK', 'LK',
    'DGLK', 'DGLK', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Inwi -> dtone (Code: 1711, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd10adfd9-ee64-43b1-abe3-3d54373d5c4c' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd10adfd9-ee64-43b1-abe3-3d54373d5c4c', 'dtone', 'MAR', 'MAR',
    '1711', '1711', 10, true, true, '🟢 Primary Direct Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Inwi -> reloadly (Code: 312, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd10adfd9-ee64-43b1-abe3-3d54373d5c4c' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd10adfd9-ee64-43b1-abe3-3d54373d5c4c', 'reloadly', 'MA', 'MA',
    '312', '312', 20, false, true, '🟢 Secondary Direct Route (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Inwi -> zendit (Code: Inwi, Priority: 50, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd10adfd9-ee64-43b1-abe3-3d54373d5c4c' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd10adfd9-ee64-43b1-abe3-3d54373d5c4c', 'zendit', 'MA', 'MA',
    'Inwi', 'Inwi', 50, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 50`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [MA] Inwi -> ding (Code: INMA, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd10adfd9-ee64-43b1-abe3-3d54373d5c4c' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd10adfd9-ee64-43b1-abe3-3d54373d5c4c', 'ding', 'MA', 'MA',
    'INMA', 'INMA', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Ncell -> dtone (Code: 1442, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895', 'dtone', 'NPL', 'NPL',
    '1442', '1442', 10, true, true, '🟢 Primary Direct Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Ncell -> reloadly (Code: 328, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895', 'reloadly', 'NP', 'NP',
    '328', '328', 20, false, true, '🟢 Secondary Direct Route (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Ncell -> zendit (Code: Ncell, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895', 'zendit', 'NP', 'NP',
    'Ncell', 'Ncell', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [NP] Ncell -> ding (Code: NCNP, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '7ea0f6f4-ec7f-4d3d-b5b9-55b3c2ab2895', 'ding', 'NP', 'NP',
    'NCNP', 'NCNP', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Renna Mobile -> dtone (Code: 2697, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '67ae4e83-9b19-4168-9140-a83ccb0af44b' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '67ae4e83-9b19-4168-9140-a83ccb0af44b', 'dtone', 'OMN', 'OMN',
    '2697', '2697', 10, true, true, '🟢 Primary Micro-PIN Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Renna Mobile -> reloadly (Code: 349, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '67ae4e83-9b19-4168-9140-a83ccb0af44b' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '67ae4e83-9b19-4168-9140-a83ccb0af44b', 'reloadly', 'OM', 'OM',
    '349', '349', 20, false, true, '🟢 Secondary PIN Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Renna Mobile -> ding (Code: Renna, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '67ae4e83-9b19-4168-9140-a83ccb0af44b' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '67ae4e83-9b19-4168-9140-a83ccb0af44b', 'ding', 'OM', 'OM',
    'Renna', 'Renna', 30, false, false, '🔴 Disabled (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [OM] Renna Mobile -> zendit (Code: Renna, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '67ae4e83-9b19-4168-9140-a83ccb0af44b' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '67ae4e83-9b19-4168-9140-a83ccb0af44b', 'zendit', 'OM', 'OM',
    'Renna', 'Renna', 40, false, false, '🔴 Disabled (`priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Jazz -> dtone (Code: 400, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ed074f20-1809-4665-abfe-9c571d11b4e3' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ed074f20-1809-4665-abfe-9c571d11b4e3', 'dtone', 'PAK', 'PAK',
    '400', '400', 10, true, true, '🟢 Primary Direct Top-Up (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Jazz -> reloadly (Code: 354, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ed074f20-1809-4665-abfe-9c571d11b4e3' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ed074f20-1809-4665-abfe-9c571d11b4e3', 'reloadly', 'PK', 'PK',
    '354', '354', 20, false, true, '🟢 Secondary Direct Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Jazz -> zendit (Code: Jazz, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ed074f20-1809-4665-abfe-9c571d11b4e3' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ed074f20-1809-4665-abfe-9c571d11b4e3', 'zendit', 'PK', 'PK',
    'Jazz', 'Jazz', 30, false, true, '🟢 Tertiary Direct Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Jazz -> ding (Code: MBPK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'ed074f20-1809-4665-abfe-9c571d11b4e3' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'ed074f20-1809-4665-abfe-9c571d11b4e3', 'ding', 'PK', 'PK',
    'MBPK', 'MBPK', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Telenor Pakistan -> dtone (Code: 655, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1b30419d-d8cc-4e5c-ba69-69ad1db1d827' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1b30419d-d8cc-4e5c-ba69-69ad1db1d827', 'dtone', 'PAK', 'PAK',
    '655', '655', 10, true, true, '🟢 Primary Direct Top-Up (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Telenor Pakistan -> reloadly (Code: 353, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1b30419d-d8cc-4e5c-ba69-69ad1db1d827' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1b30419d-d8cc-4e5c-ba69-69ad1db1d827', 'reloadly', 'PK', 'PK',
    '353', '353', 20, false, true, '🟢 Secondary Direct Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Telenor Pakistan -> zendit (Code: Telenor, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1b30419d-d8cc-4e5c-ba69-69ad1db1d827' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1b30419d-d8cc-4e5c-ba69-69ad1db1d827', 'zendit', 'PK', 'PK',
    'Telenor', 'Telenor', 30, false, true, '🟢 Tertiary Direct Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Telenor Pakistan -> ding (Code: TPPK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '1b30419d-d8cc-4e5c-ba69-69ad1db1d827' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '1b30419d-d8cc-4e5c-ba69-69ad1db1d827', 'ding', 'PK', 'PK',
    'TPPK', 'TPPK', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Ufone -> dtone (Code: 486, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'c9610c03-e9b0-4652-824e-05819c750434' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'c9610c03-e9b0-4652-824e-05819c750434', 'dtone', 'PAK', 'PAK',
    '486', '486', 10, true, true, '🟢 Primary Direct Top-Up (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Ufone -> reloadly (Code: 355, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'c9610c03-e9b0-4652-824e-05819c750434' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'c9610c03-e9b0-4652-824e-05819c750434', 'reloadly', 'PK', 'PK',
    '355', '355', 20, false, true, '🟢 Secondary Direct Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Ufone -> zendit (Code: Ufone, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'c9610c03-e9b0-4652-824e-05819c750434' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'c9610c03-e9b0-4652-824e-05819c750434', 'zendit', 'PK', 'PK',
    'Ufone', 'Ufone', 30, false, true, '🟢 Tertiary Direct Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Ufone -> ding (Code: UFPK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'c9610c03-e9b0-4652-824e-05819c750434' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'c9610c03-e9b0-4652-824e-05819c750434', 'ding', 'PK', 'PK',
    'UFPK', 'UFPK', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Zong -> dtone (Code: 1515, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd11255ef-6919-4280-91bd-70199fba5253' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd11255ef-6919-4280-91bd-70199fba5253', 'dtone', 'PAK', 'PAK',
    '1515', '1515', 10, true, true, '🟢 Primary Direct Top-Up (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Zong -> reloadly (Code: 352, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd11255ef-6919-4280-91bd-70199fba5253' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd11255ef-6919-4280-91bd-70199fba5253', 'reloadly', 'PK', 'PK',
    '352', '352', 20, false, true, '🟢 Secondary Direct Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Zong -> zendit (Code: Zong, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd11255ef-6919-4280-91bd-70199fba5253' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd11255ef-6919-4280-91bd-70199fba5253', 'zendit', 'PK', 'PK',
    'Zong', 'Zong', 30, false, true, '🟢 Tertiary Direct Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PK] Zong -> ding (Code: ZNPK, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'd11255ef-6919-4280-91bd-70199fba5253' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'd11255ef-6919-4280-91bd-70199fba5253', 'ding', 'PK', 'PK',
    'ZNPK', 'ZNPK', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] DITO Telecommunity -> zendit (Code: Dito, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '0ca2d774-fca1-4d2f-845a-f38babee4adc' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '0ca2d774-fca1-4d2f-845a-f38babee4adc', 'zendit', 'PH', 'PH',
    'Dito', 'Dito', 10, true, true, '🟢 Primary Direct (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] DITO Telecommunity -> reloadly (Code: 1182, Priority: 20, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '0ca2d774-fca1-4d2f-845a-f38babee4adc' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '0ca2d774-fca1-4d2f-845a-f38babee4adc', 'reloadly', 'PH', 'PH',
    '1182', '1182', 20, false, false, '🔴 Secondary Failover (`is_enabled: false`, `priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] DITO Telecommunity -> dtone (Code: Unsupported in Pre-Prod, Priority: 30, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '0ca2d774-fca1-4d2f-845a-f38babee4adc' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '0ca2d774-fca1-4d2f-845a-f38babee4adc', 'dtone', 'PHL', 'PHL',
    'Unsupported in Pre-Prod', 'Unsupported in Pre-Prod', 30, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] DITO Telecommunity -> ding (Code: DWPH, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '0ca2d774-fca1-4d2f-845a-f38babee4adc' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '0ca2d774-fca1-4d2f-845a-f38babee4adc', 'ding', 'PH', 'PH',
    'DWPH', 'DWPH', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Globe Telecom -> dtone (Code: 246, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4', 'dtone', 'PHL', 'PHL',
    '246', '246', 10, true, true, '🟢 Primary Direct (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Globe Telecom -> reloadly (Code: 371, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4', 'reloadly', 'PH', 'PH',
    '371', '371', 20, false, true, '🟢 Secondary Direct (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Globe Telecom -> zendit (Code: Globe, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4', 'zendit', 'PH', 'PH',
    'Globe', 'Globe', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Globe Telecom -> ding (Code: GBPH, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4', 'ding', 'PH', 'PH',
    'GBPH', 'GBPH', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Smart Communications -> dtone (Code: 570, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f259b40b-3d06-4fb2-b765-edb0d01df788' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f259b40b-3d06-4fb2-b765-edb0d01df788', 'dtone', 'PHL', 'PHL',
    '570', '570', 10, true, true, '🟢 Primary Direct (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Smart Communications -> reloadly (Code: 372, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f259b40b-3d06-4fb2-b765-edb0d01df788' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f259b40b-3d06-4fb2-b765-edb0d01df788', 'reloadly', 'PH', 'PH',
    '372', '372', 20, false, true, '🟢 Secondary Direct (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Smart Communications -> zendit (Code: Smart, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f259b40b-3d06-4fb2-b765-edb0d01df788' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f259b40b-3d06-4fb2-b765-edb0d01df788', 'zendit', 'PH', 'PH',
    'Smart', 'Smart', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [PH] Smart Communications -> ding (Code: SMPH, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'f259b40b-3d06-4fb2-b765-edb0d01df788' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'f259b40b-3d06-4fb2-b765-edb0d01df788', 'ding', 'PH', 'PH',
    'SMPH', 'SMPH', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Red Bull Mobile KSA -> dtone (Code: Red Bull, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b09e42c4-e66f-4ab6-b7e5-70ab35ca6fbb' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b09e42c4-e66f-4ab6-b7e5-70ab35ca6fbb', 'dtone', 'SAU', 'SAU',
    'Red Bull', 'Red Bull', 40, false, false, '🔴 Disabled', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Red Bull Mobile KSA -> reloadly (Code: Red Bull, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b09e42c4-e66f-4ab6-b7e5-70ab35ca6fbb' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b09e42c4-e66f-4ab6-b7e5-70ab35ca6fbb', 'reloadly', 'SA', 'SA',
    'Red Bull', 'Red Bull', 40, false, false, '🔴 Disabled', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Red Bull Mobile KSA -> zendit (Code: Red Bull, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b09e42c4-e66f-4ab6-b7e5-70ab35ca6fbb' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b09e42c4-e66f-4ab6-b7e5-70ab35ca6fbb', 'zendit', 'SA', 'SA',
    'Red Bull', 'Red Bull', 40, false, false, '🔴 Disabled', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [SA] Red Bull Mobile KSA -> ding (Code: 3HSA, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'b09e42c4-e66f-4ab6-b7e5-70ab35ca6fbb' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'b09e42c4-e66f-4ab6-b7e5-70ab35ca6fbb', 'ding', 'SA', 'SA',
    '3HSA', '3HSA', 10, true, true, '🟢 Exclusive Primary (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Pttcell -> dtone (Code: 46, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3e9caec3-6125-4aa8-b01f-512a3fe88c18' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3e9caec3-6125-4aa8-b01f-512a3fe88c18', 'dtone', 'TUR', 'TUR',
    '46', '46', 10, true, true, '🟢 Primary Direct Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Pttcell -> reloadly (Code: 510, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3e9caec3-6125-4aa8-b01f-512a3fe88c18' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3e9caec3-6125-4aa8-b01f-512a3fe88c18', 'reloadly', 'TR', 'TR',
    '510', '510', 20, false, true, '🟢 Secondary Direct Failover (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Pttcell -> zendit (Code: TurkTelekom, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3e9caec3-6125-4aa8-b01f-512a3fe88c18' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3e9caec3-6125-4aa8-b01f-512a3fe88c18', 'zendit', 'TR', 'TR',
    'TurkTelekom', 'TurkTelekom', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Pttcell -> ding (Code: AVTR, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = '3e9caec3-6125-4aa8-b01f-512a3fe88c18' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    '3e9caec3-6125-4aa8-b01f-512a3fe88c18', 'ding', 'TR', 'TR',
    'AVTR', 'AVTR', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Turkcell -> dtone (Code: 679, Priority: 20, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'fe1eb878-c1d2-4a01-8510-7f938c73712e' AND provider <> 'dtone' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'fe1eb878-c1d2-4a01-8510-7f938c73712e', 'dtone', 'TUR', 'TUR',
    '679', '679', 20, false, true, '🟢 Secondary Direct Route (`priority: 20`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Turkcell -> reloadly (Code: 509, Priority: 10, Primary: true, Enabled: true)
DO $$
BEGIN
  IF true THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'fe1eb878-c1d2-4a01-8510-7f938c73712e' AND provider <> 'reloadly' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'fe1eb878-c1d2-4a01-8510-7f938c73712e', 'reloadly', 'TR', 'TR',
    '509', '509', 10, true, true, '🟢 Primary Micro-Refill Route (`is_primary: true`, `priority: 10`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Turkcell -> zendit (Code: Turkcell, Priority: 30, Primary: false, Enabled: true)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'fe1eb878-c1d2-4a01-8510-7f938c73712e' AND provider <> 'zendit' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'fe1eb878-c1d2-4a01-8510-7f938c73712e', 'zendit', 'TR', 'TR',
    'Turkcell', 'Turkcell', 30, false, true, '🟢 Tertiary Failover (`priority: 30`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;

-- Mapping: [TR] Turkcell -> ding (Code: TZTR, Priority: 40, Primary: false, Enabled: false)
DO $$
BEGIN
  IF false THEN
    UPDATE public.carrier_provider_map
       SET is_primary = false, updated_at = now()
     WHERE carrier_id = 'fe1eb878-c1d2-4a01-8510-7f938c73712e' AND provider <> 'ding' AND is_primary;
  END IF;

  INSERT INTO public.carrier_provider_map (
    carrier_id, provider, provider_country_code, provider_country_label,
    provider_carrier_code, provider_carrier_label, priority, is_primary, is_enabled, notes, updated_at
  )
  VALUES (
    'fe1eb878-c1d2-4a01-8510-7f938c73712e', 'ding', 'TR', 'TR',
    'TZTR', 'TZTR', 40, false, false, '🔴 Disabled (`is_enabled: false`, `priority: 40`)', now()
  )
  ON CONFLICT (carrier_id, provider) DO UPDATE SET
    provider_country_code = EXCLUDED.provider_country_code,
    provider_carrier_code = EXCLUDED.provider_carrier_code,
    priority              = EXCLUDED.priority,
    is_primary            = EXCLUDED.is_primary,
    is_enabled            = EXCLUDED.is_enabled,
    notes                 = COALESCE(EXCLUDED.notes, carrier_provider_map.notes),
    updated_at            = now();
END $$;
