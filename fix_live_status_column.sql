-- ============================================
-- FIX: Clear "Aguardando Retorno" status from Paid carts
-- ============================================

-- 1. Clean up existing records
-- Moves carts from "Aguardando Retorno" column to "Pago" column
UPDATE live_carts 
SET operational_status = NULL 
WHERE status = 'pago' 
  AND operational_status = 'aguardando_retorno';

-- 2. Create trigger to prevent this from happening again
-- (Since the Webhook doesn't automatically clear the operational_status)

CREATE OR REPLACE FUNCTION trigger_clear_operational_status_on_pay()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- If status changes to 'pago'
  IF NEW.status = 'pago' THEN
    -- And currently it is marked as waiting...
    IF OLD.operational_status IN ('aguardando_retorno', 'aguardando_pagamento') THEN
       -- Clear it so it counts as just 'Pago' (or falls back to default flow)
       NEW.operational_status := NULL;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_live_cart_pay_clear_op_status ON public.live_carts;

CREATE TRIGGER on_live_cart_pay_clear_op_status
  BEFORE UPDATE ON public.live_carts
  FOR EACH ROW
  EXECUTE FUNCTION trigger_clear_operational_status_on_pay();
