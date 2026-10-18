CREATE TABLE IF NOT EXISTS public.payment_gateways (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    fee_percentage NUMERIC NOT NULL DEFAULT 0,
    fee_fixed NUMERIC NOT NULL DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.payment_gateways ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all users" ON public.payment_gateways FOR SELECT USING (true);

-- Insert default payment gateways
INSERT INTO public.payment_gateways (code, name, fee_percentage, fee_fixed, is_active)
VALUES 
    ('wallet', 'My Wallet Balance', 0.0, 0.0, true),
    ('paypal', 'PayPal', 3.4, 0.49, true),
    ('stripe', 'Credit Card', 4.5, 0.30, true)
ON CONFLICT (code) DO NOTHING;

ALTER TABLE public.topup_executions
ADD COLUMN IF NOT EXISTS payment_gateway_code TEXT REFERENCES public.payment_gateways(code),
ADD COLUMN IF NOT EXISTS base_cost_usd NUMERIC,
ADD COLUMN IF NOT EXISTS gateway_fee_usd NUMERIC,
ADD COLUMN IF NOT EXISTS app_fee_usd NUMERIC;

-- Create the trigger function
CREATE OR REPLACE FUNCTION public.calculate_topup_fees()
RETURNS TRIGGER AS $$
DECLARE
    pm RECORD;
BEGIN
    -- Only calculate if we have a payment gateway and base cost
    IF NEW.payment_gateway_code IS NOT NULL AND NEW.base_cost_usd IS NOT NULL THEN
        -- Get the payment gateway fees
        SELECT * INTO pm FROM public.payment_gateways WHERE code = NEW.payment_gateway_code;
        
        IF FOUND THEN
            -- Calculate Gateway Fee: (Base * Percentage) + Fixed
            NEW.gateway_fee_usd := ROUND((NEW.base_cost_usd * (pm.fee_percentage / 100.0) + pm.fee_fixed), 2);
            
            -- Calculate App Fee: (Base * 5%)
            NEW.app_fee_usd := ROUND((NEW.base_cost_usd * 0.05), 2);
            
            -- Calculate Final Amount
            NEW.amount := ROUND(NEW.base_cost_usd + NEW.gateway_fee_usd + NEW.app_fee_usd, 2);
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS tr_calculate_topup_fees ON public.topup_executions;
CREATE TRIGGER tr_calculate_topup_fees
BEFORE INSERT ON public.topup_executions
FOR EACH ROW
EXECUTE FUNCTION public.calculate_topup_fees();
