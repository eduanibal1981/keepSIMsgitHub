-- Trigger to update sim_lines.last_topup_at when topup_executions succeeds

CREATE OR REPLACE FUNCTION update_sim_line_last_topup_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.status = 'success' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'success') THEN
        UPDATE public.sim_lines
        SET last_topup_at = COALESCE(NEW.completed_at, now()),
            updated_at = now()
        WHERE id = NEW.sim_line_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_update_sim_line_last_topup ON public.topup_executions;

CREATE TRIGGER trigger_update_sim_line_last_topup
AFTER INSERT OR UPDATE OF status ON public.topup_executions
FOR EACH ROW
EXECUTE FUNCTION update_sim_line_last_topup_at();
