-- Migration: 20260721010000_dtone_carrier_mappings.sql
-- Populate dt_country and dt_carrier mappings for target carriers.

UPDATE public.carriers
SET dt_country = co.iso_code,
    dt_carrier = CASE 
      WHEN carriers.name = 'AT&T' THEN 'AT&T'
      WHEN carriers.name = 'Mint Mobile' THEN 'Mint Mobile'
      WHEN carriers.name = 'T-Mobile' THEN 'T-Mobile'
      WHEN carriers.name = 'Verizon' THEN 'Verizon'
      WHEN carriers.name = 'EE' THEN 'EE'
      WHEN carriers.name = 'O2 UK' THEN 'O2'
      WHEN carriers.name = 'Three UK' THEN 'Three'
      WHEN carriers.name = 'Vodafone UK' THEN 'Vodafone'
      WHEN carriers.name = 'Zain KSA' THEN 'Zain'
      WHEN carriers.name = 'Mobily' THEN 'Mobily'
      WHEN carriers.name = 'STC' THEN 'STC'
      WHEN carriers.name = 'Zain Kuwait' THEN 'Zain'
      WHEN carriers.name = 'Ooredoo Kuwait' THEN 'Ooredoo'
      WHEN carriers.name = 'STC Kuwait' THEN 'STC'
      WHEN carriers.name = 'Omantel' THEN 'Omantel'
      WHEN carriers.name = 'Ooredoo Oman' THEN 'Ooredoo'
      WHEN carriers.name = 'Umniah' THEN 'Umniah'
      WHEN carriers.name = 'Virgin Mobile UAE' THEN 'Virgin Mobile'
      ELSE carriers.zen_carrier
    END
FROM public.countries co
WHERE co.id = carriers.country_id
  AND co.iso_code IN ('US', 'GB', 'SA', 'KW', 'OM', 'JO', 'AE');

-- Set Zain KSA to api_provider = 'dtone' as verified first DTone target
UPDATE public.carriers
SET api_provider = 'dtone'
WHERE name = 'Zain KSA';
