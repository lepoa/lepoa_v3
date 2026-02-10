
-- REMOVE CATCH BLOCKS TO SEE REAL ERRORS
-- AND DROP DEPENDENCIES

-- 1. Drop trigger first
DROP TRIGGER IF EXISTS on_live_cart_sync_to_orders ON public.live_carts;

-- 2. Drop function
DROP FUNCTION IF EXISTS public.sync_live_cart_to_orders(uuid);

-- 3. Alter columns (Forcefully)
ALTER TABLE public.live_cart_items 
ALTER COLUMN variante TYPE JSONB USING to_jsonb(variante);

ALTER TABLE public.live_carts 
ALTER COLUMN shipping_address_snapshot TYPE JSONB USING to_jsonb(shipping_address_snapshot);


-- 4. Recreate Function
CREATE OR REPLACE FUNCTION public.sync_live_cart_to_orders(p_live_cart_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_cart RECORD;
  v_customer RECORD;
  v_existing_order_id uuid;
  v_order_id uuid;
  v_address_snapshot jsonb;
  v_customer_name text;
  v_customer_phone text;
  v_full_address text;
BEGIN
  -- Get live cart with items
  SELECT 
    lc.*,
    le.titulo as live_title,
    lcust.instagram_handle,
    lcust.nome as customer_nome,
    lcust.whatsapp as customer_whatsapp,
    lcust.client_id
  INTO v_cart
  FROM live_carts lc
  JOIN live_events le ON le.id = lc.live_event_id
  JOIN live_customers lcust ON lcust.id = lc.live_customer_id
  WHERE lc.id = p_live_cart_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Live cart not found');
  END IF;

  SELECT id INTO v_existing_order_id FROM orders WHERE live_cart_id = p_live_cart_id;

  IF v_cart.client_id IS NOT NULL THEN
    SELECT * INTO v_customer FROM customers WHERE id = v_cart.client_id;
    v_customer_name := COALESCE(v_customer.name, v_cart.customer_nome, v_cart.instagram_handle);
    v_customer_phone := COALESCE(v_customer.phone, v_cart.customer_whatsapp, '');
  ELSE
    v_customer_name := COALESCE(v_cart.customer_nome, v_cart.instagram_handle);
    v_customer_phone := COALESCE(v_cart.customer_whatsapp, '');
  END IF;

  -- Ensure JSONB
  v_address_snapshot := COALESCE(to_jsonb(v_cart.shipping_address_snapshot), '{}'::jsonb);
  
  v_full_address := COALESCE(v_address_snapshot->>'street', v_address_snapshot->>'address_line', '');
  IF v_address_snapshot->>'number' IS NOT NULL THEN
    v_full_address := v_full_address || ', ' || (v_address_snapshot->>'number');
  END IF;
  IF v_address_snapshot->>'neighborhood' IS NOT NULL THEN
    v_full_address := v_full_address || ' - ' || (v_address_snapshot->>'neighborhood');
  END IF;
  IF v_address_snapshot->>'city' IS NOT NULL THEN
    v_full_address := v_full_address || ', ' || (v_address_snapshot->>'city');
  END IF;
  IF v_address_snapshot->>'state' IS NOT NULL THEN
    v_full_address := v_full_address || ' - ' || (v_address_snapshot->>'state');
  END IF;

  IF v_existing_order_id IS NOT NULL THEN
    UPDATE orders SET
      status = CASE v_cart.status WHEN 'pago' THEN 'pago' WHEN 'cancelado' THEN 'cancelado' ELSE 'aguardando_pagamento' END,
      customer_name = v_customer_name,
      customer_phone = v_customer_phone,
      customer_address = v_full_address,
      subtotal = v_cart.subtotal,
      total = v_cart.total,
      shipping_fee = v_cart.frete,
      delivery_method = v_cart.delivery_method,
      delivery_period = v_cart.delivery_period,
      delivery_notes = v_cart.delivery_notes,
      address_snapshot = v_address_snapshot,
      updated_at = now()
    WHERE id = v_existing_order_id;
    v_order_id := v_existing_order_id;
  ELSE
    INSERT INTO orders (
      source, live_cart_id, live_event_id, live_bag_number,
      customer_name, customer_phone, customer_address,
      subtotal, total, shipping_fee,
      delivery_method, delivery_period, delivery_notes,
      address_snapshot, seller_id, paid_at, status, payment_status
    ) VALUES (
      'live', p_live_cart_id, v_cart.live_event_id, v_cart.bag_number,
      v_customer_name, v_customer_phone, v_full_address,
      v_cart.subtotal, v_cart.total, v_cart.frete,
      v_cart.delivery_method, v_cart.delivery_period, v_cart.delivery_notes,
      v_address_snapshot, v_cart.seller_id, v_cart.paid_at,
      CASE v_cart.status WHEN 'pago' THEN 'pago' WHEN 'cancelado' THEN 'cancelado' ELSE 'aguardando_pagamento' END,
      CASE v_cart.status WHEN 'pago' THEN 'approved' ELSE 'pending' END
    )
    RETURNING id INTO v_order_id;

    INSERT INTO order_items (order_id, product_id, product_name, product_price, quantity, size, color, image_url, product_sku)
    SELECT 
      v_order_id, lci.product_id, COALESCE(pc.name, 'Produto'), lci.preco_unitario, lci.qtd,
      COALESCE(lci.variante->>'tamanho', ''),
      pc.color, pc.image_url, pc.sku
    FROM live_cart_items lci
    LEFT JOIN product_catalog pc ON pc.id = lci.product_id
    WHERE lci.live_cart_id = p_live_cart_id AND lci.status NOT IN ('cancelado', 'removido');
  END IF;

  UPDATE live_carts SET order_id = v_order_id WHERE id = p_live_cart_id;

  RETURN jsonb_build_object('success', true, 'order_id', v_order_id);
END;
$$;

-- 5. Recreate Trigger
CREATE OR REPLACE FUNCTION public.trigger_sync_live_cart_to_orders()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.status IN ('aguardando_pagamento', 'cobrado', 'pago', 'cancelado', 'expirado') 
     OR (NEW.status = 'pago' AND OLD.status IS DISTINCT FROM 'pago')
     OR (NEW.operational_status IS DISTINCT FROM OLD.operational_status AND NEW.status = 'pago') THEN
    PERFORM public.sync_live_cart_to_orders(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_live_cart_sync_to_orders
  AFTER UPDATE ON public.live_carts
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_sync_live_cart_to_orders();
