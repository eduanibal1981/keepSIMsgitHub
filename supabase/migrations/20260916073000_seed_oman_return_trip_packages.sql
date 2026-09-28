-- Seed return trip / local data packages for Oman (country ISO 'OM')
DO $$
DECLARE
  v_oman_id UUID;
  v_omantel_id UUID;
  v_ooredoo_id UUID;
BEGIN
  SELECT id INTO v_oman_id FROM public.countries WHERE iso_code = 'OM' LIMIT 1;
  IF v_oman_id IS NOT NULL THEN
    SELECT id INTO v_omantel_id FROM public.carriers WHERE country_id = v_oman_id AND name ILIKE '%Omantel%' LIMIT 1;
    SELECT id INTO v_ooredoo_id FROM public.carriers WHERE country_id = v_oman_id AND name ILIKE '%Ooredoo%' LIMIT 1;

    -- 1. eSIM: 1-Day Unlimited Travel eSIM for Oman
    INSERT INTO public.return_trip_packages (
      country_id, carrier_id, package_type, title, description,
      data_allowance_mb, duration_days, is_unlimited,
      supplier_cost_usd, retail_price_usd,
      activation_instructions, badge_label, is_active
    ) VALUES (
      v_oman_id, NULL, 'esim', '1-Day Unlimited Travel eSIM', 'Unlimited high-speed data for 24 hours upon landing in Oman.',
      -1, 1, true,
      2.50, 3.50,
      'Scan QR code upon landing at Muscat/Salalah or install before boarding.', 'Cheapest 1-Day Unlimited', true
    ) ON CONFLICT DO NOTHING;

    -- 2. Omantel: 12GB Hayyak Pack
    IF v_omantel_id IS NOT NULL THEN
      INSERT INTO public.return_trip_packages (
        country_id, carrier_id, package_type, title, description,
        data_allowance_mb, duration_days, is_unlimited,
        supplier_cost_usd, retail_price_usd,
        ussd_recharge_code, activation_instructions, badge_label, is_active
      ) VALUES (
        v_oman_id, v_omantel_id, 'carrier_ussd', 'Omantel 12GB Hayyak Pack', '12GB high-speed local data valid for 4 weeks.',
        12288, 28, false,
        12.00, 14.00,
        '*666*4*PIN#', 'Dial *666*4*PIN# from your Omantel SIM to activate 12GB.', 'Popular Local Data', true
      ) ON CONFLICT DO NOTHING;

      -- 3. Omantel: 5 OMR Data Credit
      INSERT INTO public.return_trip_packages (
        country_id, carrier_id, package_type, title, description,
        data_allowance_mb, duration_days, is_unlimited,
        supplier_cost_usd, retail_price_usd,
        ussd_recharge_code, activation_instructions, badge_label, is_active
      ) VALUES (
        v_oman_id, v_omantel_id, 'carrier_ussd', 'Omantel 5 OMR Data Credit', '5 OMR credit for standard data & 180-day keep-alive validity.',
        5120, 180, false,
        6.20, 7.50,
        '*101*PIN#', 'Dial *101*PIN# to recharge 5 OMR on your Omantel SIM.', '180-Day Keep-Alive', true
      ) ON CONFLICT DO NOTHING;
    END IF;

    -- 4. Ooredoo Oman: 5GB Shababiah Pass
    IF v_ooredoo_id IS NOT NULL THEN
      INSERT INTO public.return_trip_packages (
        country_id, carrier_id, package_type, title, description,
        data_allowance_mb, duration_days, is_unlimited,
        supplier_cost_usd, retail_price_usd,
        ussd_recharge_code, activation_instructions, badge_label, is_active
      ) VALUES (
        v_oman_id, v_ooredoo_id, 'carrier_ussd', 'Ooredoo 5GB Shababiah Pass', '5GB high-speed data valid for 7 days.',
        5120, 7, false,
        4.00, 5.50,
        '*115*PIN#', 'Dial *115*PIN# on Ooredoo Oman network.', 'Fast 4G Data', true
      ) ON CONFLICT DO NOTHING;
    END IF;
  END IF;
END $$;
