-- Migration: Split fulfillment queue architecture
ALTER TABLE public.topup_executions
ADD COLUMN IF NOT EXISTS execution_type VARCHAR,
ADD COLUMN IF NOT EXISTS execution_time TIMESTAMPTZ DEFAULT NOW();

-- Create the queue claiming RPC
CREATE OR REPLACE FUNCTION public.claim_due_executions(p_execution_type VARCHAR, p_limit INT)
RETURNS SETOF public.topup_executions AS $$
BEGIN
  RETURN QUERY
  UPDATE public.topup_executions
  SET status = 'processing'
  WHERE id IN (
    SELECT id FROM public.topup_executions
    WHERE status = 'pending' 
      AND execution_type = p_execution_type
      AND execution_time <= NOW()
    ORDER BY execution_time ASC
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED
  )
  RETURNING *;
END;
$$ LANGUAGE plpgsql;
