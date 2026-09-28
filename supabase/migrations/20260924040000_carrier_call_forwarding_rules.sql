-- ============================================================================
-- Migration: 20260924040000_carrier_call_forwarding_rules.sql
-- Feature: Real-Data Carrier MMI Call Diversion Codes for Smart Calling
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.carrier_call_forwarding_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  carrier_id UUID NOT NULL REFERENCES public.carriers(id) ON DELETE CASCADE,
  country_code TEXT NOT NULL,
  cfu_format TEXT NOT NULL DEFAULT '**21*{number}#',
  cfu_cancel TEXT NOT NULL DEFAULT '##21#',
  cfu_status TEXT NOT NULL DEFAULT '*#21#',
  cfb_format TEXT NOT NULL DEFAULT '**67*{number}#',
  cfb_cancel TEXT NOT NULL DEFAULT '##67#',
  cfnry_format TEXT NOT NULL DEFAULT '**61*{number}#',
  cfnry_cancel TEXT NOT NULL DEFAULT '##61#',
  cfnrc_format TEXT NOT NULL DEFAULT '**62*{number}#',
  cfnrc_cancel TEXT NOT NULL DEFAULT '##62#',
  cancel_all TEXT NOT NULL DEFAULT '##002#',
  special_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_carrier_call_forwarding_carrier UNIQUE (carrier_id)
);

CREATE INDEX IF NOT EXISTS idx_carrier_call_forwarding_country 
  ON public.carrier_call_forwarding_rules(country_code);

ALTER TABLE public.carrier_call_forwarding_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_carrier_call_forwarding_select ON public.carrier_call_forwarding_rules;
CREATE POLICY p_carrier_call_forwarding_select ON public.carrier_call_forwarding_rules
  FOR SELECT TO authenticated, anon
  USING (TRUE);

GRANT SELECT ON public.carrier_call_forwarding_rules TO authenticated, anon;
GRANT ALL ON public.carrier_call_forwarding_rules TO service_role;

-- 1. Seed default 3GPP GSM Supplementary Service codes for all active carriers
INSERT INTO public.carrier_call_forwarding_rules (
  carrier_id,
  country_code,
  cfu_format,
  cfu_cancel,
  cfu_status,
  cfb_format,
  cfb_cancel,
  cfnry_format,
  cfnry_cancel,
  cfnrc_format,
  cfnrc_cancel,
  cancel_all,
  special_notes
)
SELECT 
  c.id,
  co.iso_code,
  '**21*{number}#',
  '##21#',
  '*#21#',
  '**67*{number}#',
  '##67#',
  '**61*{number}#',
  '##61#',
  '**62*{number}#',
  '##62#',
  '##002#',
  CASE 
    WHEN co.iso_code IN ('SA', 'AE', 'OM', 'KW', 'BH', 'QA') THEN 'Dial code from your domestic SIM before departure. Dual-SIM: select your Home SIM in phone dialer.'
    ELSE 'Standard GSM call diversion. Dial from your domestic SIM before traveling.'
  END
FROM public.carriers c
JOIN public.countries co ON c.country_id = co.id
WHERE co.is_supported = TRUE
ON CONFLICT (carrier_id) DO UPDATE SET
  cfu_format = EXCLUDED.cfu_format,
  cfu_cancel = EXCLUDED.cfu_cancel,
  cfu_status = EXCLUDED.cfu_status,
  cancel_all = EXCLUDED.cancel_all,
  updated_at = NOW();

-- 2. Specific Exception: Reliance Jio (India) uses proprietary VoLTE Star Codes (*401*)
UPDATE public.carrier_call_forwarding_rules
SET 
  cfu_format = '*401*{number}',
  cfu_cancel = '*402',
  cfu_status = '*401',
  cfb_format = '*405*{number}',
  cfb_cancel = '*406',
  cfnry_format = '*403*{number}',
  cfnry_cancel = '*404',
  cfnrc_format = '*409*{number}',
  cfnrc_cancel = '*410',
  cancel_all = '*413',
  special_notes = 'Reliance Jio VoLTE Star Codes. For international forwarding, ensure ISD is enabled on your Jio domestic SIM before dialing.'
WHERE carrier_id = 'b76b9150-8894-41c3-a1b5-9c2c8cb07d3e';

-- 3. Specific Carrier Note: STC (Saudi Arabia)
UPDATE public.carrier_call_forwarding_rules
SET special_notes = 'STC Saudi standard GSM forwarding. Dial before flight. Deactivate upon return by dialing ##21#.'
WHERE carrier_id = 'da1c57b4-5276-4814-ade4-1d5a421bc29e';

-- 4. Specific Carrier Note: Mobily (Saudi Arabia)
UPDATE public.carrier_call_forwarding_rules
SET special_notes = 'Mobily standard GSM forwarding. Dial before flight. Deactivate upon return by dialing ##21#.'
WHERE carrier_id = 'efc1729e-3fbb-43c1-8297-37754732aeed';

-- 5. Specific Carrier Note: Zain KSA
UPDATE public.carrier_call_forwarding_rules
SET special_notes = 'Zain Saudi standard GSM forwarding. Dial before flight. Deactivate upon return by dialing ##21#.'
WHERE carrier_id = 'a03cee64-eea7-4ec7-a234-dc8a625a354e';

-- 6. Specific Carrier Note: Etisalat UAE (e&)
UPDATE public.carrier_call_forwarding_rules
SET special_notes = 'Etisalat (e&) standard GSM forwarding. Dial before departure. Deactivate upon return by dialing ##21#.'
WHERE carrier_id = '28905875-2684-40a3-bdb5-8aef0497ea99';

-- 7. Specific Carrier Note: du UAE
UPDATE public.carrier_call_forwarding_rules
SET special_notes = 'du UAE standard GSM forwarding. Dial before departure. Deactivate upon return by dialing ##21#.'
WHERE carrier_id = '85fbac73-d5bd-460e-b4f4-68d49d66ed23';

-- 8. Specific Carrier Note: Omantel
UPDATE public.carrier_call_forwarding_rules
SET special_notes = 'Omantel standard GSM forwarding. Dial before flight. Deactivate upon return by dialing ##21#.'
WHERE carrier_id = '8e789341-fe2a-402c-842c-0d769ccfc516';

-- 9. Security Definer RPC: Get Supported Carriers with Divert Codes
CREATE OR REPLACE FUNCTION public.get_supported_carriers_divert()
RETURNS TABLE (
  carrier_id UUID,
  carrier_name TEXT,
  country_code TEXT,
  country_name TEXT,
  flag_emoji TEXT,
  dialing_code TEXT,
  cfu_format TEXT,
  cfu_cancel TEXT,
  cfu_status TEXT,
  cancel_all TEXT,
  special_notes TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id AS carrier_id,
    c.name AS carrier_name,
    co.iso_code AS country_code,
    co.name AS country_name,
    co.flag_emoji,
    co.dialing_code,
    COALESCE(r.cfu_format, '**21*{number}#') AS cfu_format,
    COALESCE(r.cfu_cancel, '##21#') AS cfu_cancel,
    COALESCE(r.cfu_status, '*#21#') AS cfu_status,
    COALESCE(r.cancel_all, '##002#') AS cancel_all,
    r.special_notes
  FROM public.carriers c
  JOIN public.countries co ON c.country_id = co.id
  LEFT JOIN public.carrier_call_forwarding_rules r ON r.carrier_id = c.id
  WHERE co.is_supported = TRUE AND c.is_supported = TRUE
  ORDER BY co.name ASC, c.name ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_supported_carriers_divert() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_supported_carriers_divert() TO anon, authenticated, service_role;
