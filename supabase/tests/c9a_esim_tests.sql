BEGIN;

-- 1. Test esim_offers_cache insertion
INSERT INTO public.esim_offers_cache (
  provider, bundle_name, description, countries, roaming_enabled, data_amount_mb, duration_days, wholesale_price_usd, image_url
) VALUES (
  'esim_go', 'test_bundle_10gb', 'Test 10GB Europe', ARRAY['FR','DE','ES'], ARRAY['FR','DE','ES'], 10240, 30, 10.0000, 'https://example.com/art.png'
);

-- 2. Verify view esim_offers calculates retail price with 30% markup (10.00 * 1.30 = 13.00)
DO $$
DECLARE
  v_retail NUMERIC;
BEGIN
  SELECT retail_price_usd INTO v_retail FROM public.esim_offers WHERE bundle_name = 'test_bundle_10gb';
  IF v_retail <> 13.00 THEN
    RAISE EXCEPTION 'Retail price calculation mismatch: expected 13.00, got %', v_retail;
  END IF;
END $$;

-- 3. Verify esim_low_data category insertion in notifications
INSERT INTO public.notifications (user_id, category, title, body)
SELECT id, 'esim_low_data', 'Test Low Data', 'Less than 20% remaining'
FROM public.profiles LIMIT 1;

ROLLBACK;
