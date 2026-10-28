BEGIN;
SET LOCAL lock_timeout='5s';
ALTER VIEW public.customer_esim_orders SET (security_invoker=true,security_barrier=true);
GRANT SELECT(operation_kind) ON public.esim_orders TO authenticated;
ALTER FUNCTION public.request_esim_purchase_v2(text,integer,text,uuid,numeric,uuid) SET search_path='';
CREATE INDEX esim_settlement_tx_lookup ON esim_private.order_runs(settlement_tx_id) WHERE settlement_tx_id IS NOT NULL;
NOTIFY pgrst,'reload schema';
COMMIT;
