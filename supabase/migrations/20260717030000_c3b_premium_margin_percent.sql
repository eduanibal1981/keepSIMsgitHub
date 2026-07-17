-- C3b: name the premium margin instead of hiding it in a mis-applied fee.
--
-- carrier_rules.inapp_pricing stored (minimum_topup_amount + 0.30) * 1.08 — a
-- frozen snapshot of $0.30 + 5% (Stripe's fixed fee, though premium bills
-- through PayPal) plus an 8% that predates APP_FEE_PERCENT being 3. It also
-- applied that fixed fee once per refill: 13 x $0.30 to cover a single $0.49
-- PayPal charge, since premium is billed once yearly. The ~$5.88/line that
-- over-recovery collected was margin wearing a fee's clothing.
--
-- The premium quote is now computed from payment_gateways (the source of truth
-- for what a gateway charges) + APP_FEE_PERCENT, with the gateway grossed up
-- once over the yearly total, and any margin stated here where it can be
-- changed in one row with no app update.
--
-- Defaulted to 0 deliberately: the old over-recovery implied a different rate
-- for every carrier (~2.7% for O2 Germany, ~5.2% for Turkcell) because a fixed
-- fee per refill is not a percentage, so no single number reproduces it and
-- picking one is a pricing decision, not a migration's job. Setting it to 3
-- lands within ~1% of the old prices.
INSERT INTO public.system_configs (config_key, config_value)
VALUES ('PREMIUM_MARGIN_PERCENT', '0')
ON CONFLICT (config_key) DO NOTHING;
