-- C3b: the premium margin has two parts, because one number cannot describe it.
--
-- The stored carrier_rules.inapp_pricing decomposes exactly as
--   cost + 3% app fee + (5% * cost + 0.324)
-- and that last bracket was labelled "PayPal fees (0.30 + 5%)". It is not a fee:
-- it was charged once per refill while PayPal bills once per *year*, so a
-- 13-refill plan collected 13 x $0.324 = $4.21 against a real PayPal charge of
-- ~$9.90 on the yearly total. The surplus was margin nobody had named — worth
-- ~$6.78/yr on O2 Germany and ~$3.63 on Grameenphone.
--
-- It needs two knobs because it is not a percentage: the flat part is ~2.6% of a
-- $277 plan but ~41% of a $13 one, so no single PREMIUM_MARGIN_PERCENT can
-- reproduce it (matching O2 at 3% would roughly halve Grameenphone's margin).
--
-- At 5 + 0.324 every carrier's per-refill margin is identical to today's, now
-- stated instead of disguised. PayPal is separately grossed up once over the
-- yearly total, so the margin survives the gateway rather than being eaten by
-- it — which is why profit rises even though the margin itself is unchanged.
-- Both move in one row with no app update, which is the whole point.
UPDATE public.system_configs
SET config_value = '5', updated_at = now()
WHERE config_key = 'PREMIUM_MARGIN_PERCENT';

INSERT INTO public.system_configs (config_key, config_value)
VALUES ('PREMIUM_MARGIN_PER_REFILL_USD', '0.324')
ON CONFLICT (config_key) DO NOTHING;
