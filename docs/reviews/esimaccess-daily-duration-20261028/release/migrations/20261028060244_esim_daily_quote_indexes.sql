BEGIN;
SET LOCAL lock_timeout='5s';
CREATE INDEX daily_purchase_quotes_account ON esim_private.daily_purchase_quotes(account_id);
CREATE INDEX daily_purchase_quotes_price ON esim_private.daily_purchase_quotes(price_id);
CREATE INDEX recharge_quotes_daily_price ON esim_private.recharge_quotes(daily_price_id) WHERE daily_price_id IS NOT NULL;
COMMIT;

