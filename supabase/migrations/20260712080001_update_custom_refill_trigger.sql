-- Migration to enhance the trigger to automatically schedule the next refill_custom

CREATE OR REPLACE FUNCTION update_sim_line_last_topup_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_freq INTEGER;
BEGIN
    IF NEW.status = 'success' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'success') THEN
        -- 1. Update sim_lines last_topup_at
        UPDATE public.sim_lines
        SET last_topup_at = COALESCE(NEW.completed_at, now()),
            updated_at = now()
        WHERE id = NEW.sim_line_id;
        
        -- 2. Handle next execution for refill_custom
        IF NEW.execution_type = 'refill_custom' AND NEW.scheduled_topup_id IS NOT NULL THEN
            SELECT frequency_days INTO v_freq 
            FROM public.scheduled_topups 
            WHERE id = NEW.scheduled_topup_id 
            AND is_active = true;
            
            IF v_freq IS NOT NULL AND v_freq > 0 THEN
                -- Insert next execution row
                INSERT INTO public.topup_executions (
                    scheduled_topup_id, 
                    sim_line_id, 
                    user_id, 
                    amount, 
                    currency, 
                    status, 
                    execution_time, 
                    execution_type, 
                    base_cost_usd, 
                    payment_gateway_code
                ) VALUES (
                    NEW.scheduled_topup_id, 
                    NEW.sim_line_id, 
                    NEW.user_id, 
                    NEW.amount, 
                    NEW.currency, 
                    'pending', 
                    COALESCE(NEW.completed_at, now()) + (v_freq || ' days')::interval, 
                    'refill_custom', 
                    NEW.base_cost_usd, 
                    NEW.payment_gateway_code
                );
                
                -- Update scheduled_topups dates
                UPDATE public.scheduled_topups
                SET next_execution_at = COALESCE(NEW.completed_at, now()) + (v_freq || ' days')::interval,
                    last_execution_at = COALESCE(NEW.completed_at, now())
                WHERE id = NEW.scheduled_topup_id;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
