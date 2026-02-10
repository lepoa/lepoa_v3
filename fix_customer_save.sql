-- Function to save checkout details and UPDATE customer phone/name
-- ensuring we capture the data provided by the user before payment.

CREATE OR REPLACE FUNCTION public.save_live_checkout_details(
  p_cart_id UUID,
  p_token UUID,
  p_name TEXT,
  p_phone TEXT,
  p_delivery_method TEXT,
  p_delivery_period TEXT DEFAULT NULL,
  p_delivery_notes TEXT DEFAULT NULL,
  p_address_snapshot JSONB DEFAULT NULL,
  p_shipping_fee NUMERIC DEFAULT 0,
  p_shipping_service_name TEXT DEFAULT NULL,
  p_shipping_deadline_days INTEGER DEFAULT NULL,
  p_customer_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cart RECORD;
  v_total NUMERIC;
BEGIN
  -- 1. Validate cart + token
  SELECT * INTO v_cart
  FROM live_carts
  WHERE id = p_cart_id AND public_token = p_token;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Sacola não encontrada ou token inválido');
  END IF;
  
  -- Allow updates even if 'aguardando_pagamento', generally used for retries.
  -- Only block if fully paid or cancelled.
  IF v_cart.status IN ('pago', 'cancelado') THEN
    RETURN jsonb_build_object('error', 'Esta sacola não pode mais ser alterada');
  END IF;
  
  -- 2. Calculate total
  v_total := v_cart.subtotal + COALESCE(p_shipping_fee, 0);
  
  -- 3. Update cart
  UPDATE live_carts SET
    delivery_method = p_delivery_method,
    delivery_period = p_delivery_period,
    delivery_notes = p_delivery_notes,
    shipping_address_snapshot = p_address_snapshot,
    frete = COALESCE(p_shipping_fee, 0),
    total = v_total,
    shipping_service_name = p_shipping_service_name,
    shipping_deadline_days = p_shipping_deadline_days,
    customer_checkout_notes = p_customer_notes,
    status = 'aguardando_pagamento',
    updated_at = now()
  WHERE id = p_cart_id;
  
  -- 4. Update live_customer with name and phone (CRITICAL STEP)
  -- Uses explicit check to ensure we overwrite if new data is provided
  UPDATE live_customers SET
    nome = CASE WHEN p_name IS NOT NULL AND length(p_name) > 0 THEN p_name ELSE nome END,
    whatsapp = CASE WHEN p_phone IS NOT NULL AND length(p_phone) > 6 THEN p_phone ELSE whatsapp END,
    updated_at = now()
  WHERE id = v_cart.live_customer_id;
  
  RETURN jsonb_build_object('success', true, 'total', v_total);
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_live_checkout_details(UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, INTEGER, TEXT) TO anon, authenticated;
