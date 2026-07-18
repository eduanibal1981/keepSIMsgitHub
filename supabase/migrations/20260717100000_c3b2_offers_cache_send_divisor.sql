-- The manual-refill sheet shows RANGE bounds in the receiver's local currency;
-- send_min/send_max are Zendit minor units, so the divisor must travel with
-- them for display. Pricing math is unaffected (it never divides send values).
ALTER TABLE public.zendit_offers_cache ADD COLUMN send_currency_divisor numeric;