-- ============================================
-- FIX: Robustify Live Order Sync & Recovery
-- ============================================

-- 1. Updates trigger to ALWAYS ensure items usage on UPDATE
-- 2. Recovers specific broken orders by syncing items and resetting stock flags

CREATE OR REPLACE FUNCTION trigger_sync_live_cart_to_orders()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id uuid;
  v_customer_id uuid;
  v_live_customer RECORD;
  v_live_event RECORD;
  v_order_status text;
  v_customer_name text;
  v_customer_phone text;
BEGIN
  -- PROTECTION: Session flag
  IF current_setting('app.syncing_order', true) = 'true' THEN
    RETURN NEW;
  END IF;

  -- Only process relevant changes
  IF TG_OP = 'UPDATE' AND OLD.status = NEW.status 
     AND OLD.paid_at IS NOT DISTINCT FROM NEW.paid_at
     AND OLD.paid_method IS NOT DISTINCT FROM NEW.paid_method
     AND OLD.delivery_method IS NOT DISTINCT FROM NEW.delivery_method
     AND OLD.shipping_tracking_code IS NOT DISTINCT FROM NEW.shipping_tracking_code
     AND OLD.me_label_url IS NOT DISTINCT FROM NEW.me_label_url
     AND OLD.total IS NOT DISTINCT FROM NEW.total
     AND OLD.user_id IS NOT DISTINCT FROM NEW.user_id THEN
    RETURN NEW;
  END IF;

  PERFORM set_config('app.syncing_live_cart', 'true', true);

  BEGIN
    -- Get live customer info
    SELECT * INTO v_live_customer 
    FROM live_customers 
    WHERE id = NEW.live_customer_id;

    -- Get live event info
    SELECT * INTO v_live_event
    FROM live_events
    WHERE id = NEW.live_event_id;

    -- Map status
    v_order_status := CASE NEW.status::text
      WHEN 'aberto' THEN 'aguardando_pagamento'
      WHEN 'em_confirmacao' THEN 'aguardando_pagamento'
      WHEN 'aguardando_pagamento' THEN 'aguardando_pagamento'
      WHEN 'pago' THEN 'pago'
      WHEN 'cancelado' THEN 'cancelado'
      WHEN 'expirado' THEN 'cancelado'
      ELSE 'aguardando_pagamento'
    END;

    v_customer_name := COALESCE(v_live_customer.nome, v_live_customer.instagram_handle, 'Cliente Live');
    v_customer_phone := COALESCE(v_live_customer.whatsapp, '');

    -- Check if order exists
    SELECT id INTO v_order_id
    FROM orders
    WHERE live_cart_id = NEW.id;

    IF v_order_id IS NOT NULL THEN
      -- ========== UPDATE existing order ==========
      UPDATE orders SET
        status = v_order_status,
        paid_at = NEW.paid_at,
        gateway = COALESCE(NEW.paid_method, gateway),
        tracking_code = COALESCE(NEW.shipping_tracking_code, tracking_code),
        me_label_url = COALESCE(NEW.me_label_url, me_label_url),
        me_shipment_id = COALESCE(NEW.me_shipment_id, me_shipment_id),
        total = NEW.total,
        subtotal = NEW.subtotal,
        shipping_fee = NEW.frete,
        coupon_discount = NEW.descontos,
        delivery_method = COALESCE(NEW.delivery_method, delivery_method),
        address_snapshot = COALESCE(NEW.shipping_address_snapshot, address_snapshot),
        user_id = COALESCE(NEW.user_id, user_id),
        customer_name = COALESCE(NULLIF(v_customer_name, 'Cliente Live'), customer_name),
        customer_phone = CASE WHEN v_customer_phone != '' THEN v_customer_phone ELSE customer_phone END,
        updated_at = now()
      WHERE id = v_order_id;
      
      -- CRITICAL FIX: Always ensure items are synced on UPDATE too
      PERFORM ensure_order_items_for_live_order(v_order_id);
      
    ELSE
      -- ========== CREATE new order ==========
      IF NEW.status::text NOT IN ('cancelado', 'expirado') THEN
        IF v_live_customer.client_id IS NOT NULL THEN
          v_customer_id := v_live_customer.client_id;
        ELSE
          SELECT id INTO v_customer_id
          FROM customers
          WHERE (phone = v_live_customer.whatsapp AND v_live_customer.whatsapp IS NOT NULL)
             OR (instagram_handle = v_live_customer.instagram_handle AND v_live_customer.instagram_handle IS NOT NULL)
          LIMIT 1;

          IF v_customer_id IS NULL AND v_live_customer.whatsapp IS NOT NULL THEN
            INSERT INTO customers (phone, name, instagram_handle)
            VALUES (v_live_customer.whatsapp, v_live_customer.nome, v_live_customer.instagram_handle)
            RETURNING id INTO v_customer_id;
          END IF;
        END IF;

        INSERT INTO orders (
          customer_id, customer_name, customer_phone, customer_address,
          status, total, subtotal, shipping_fee, coupon_discount,
          source, live_cart_id, live_event_id, live_bag_number,
          paid_at, gateway, delivery_method, address_snapshot,
          tracking_code, me_label_url, me_shipment_id, user_id,
          reserved_until
        ) VALUES (
          v_customer_id,
          v_customer_name,
          v_customer_phone,
          '',
          v_order_status,
          NEW.total,
          NEW.subtotal,
          NEW.frete,
          NEW.descontos,
          'live',
          NEW.id,
          NEW.live_event_id,
          NEW.bag_number,
          NEW.paid_at,
          NEW.paid_method,
          NEW.delivery_method,
          NEW.shipping_address_snapshot,
          NEW.shipping_tracking_code,
          NEW.me_label_url,
          NEW.me_shipment_id,
          NEW.user_id,
          now() + (COALESCE(v_event.reservation_expiry_minutes, 10080) || ' minutes')::interval
        )
        RETURNING id INTO v_order_id;

        UPDATE live_carts SET order_id = v_order_id WHERE id = NEW.id;
        PERFORM ensure_order_items_for_live_order(v_order_id);
      END IF;
    END IF;

  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[sync_trigger] ERROR for cart %: % (SQLSTATE: %)', NEW.id, SQLERRM, SQLSTATE;
  END;

  PERFORM set_config('app.syncing_live_cart', 'false', true);
  RETURN NEW;
END;
$$;

-- ============================================
-- RECOVERY: Fix broken orders
-- ============================================
DO $$
DECLARE
  v_cart RECORD;
  v_order_id uuid;
  v_items_synced boolean;
BEGIN
  -- Find paid live carts where the order has no items
  FOR v_cart IN 
    SELECT lc.id, lc.order_id 
    FROM live_carts lc
    JOIN orders o ON o.live_cart_id = lc.id
    WHERE lc.status = 'pago' 
      AND NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.id)
  LOOP
    RAISE NOTICE 'Recovering order items for live_cart % (order %)', v_cart.id, v_cart.order_id;
    
    -- 1. Sync items
    SELECT ensure_order_items_for_live_order(v_cart.order_id) INTO v_items_synced;
    
    -- 2. Reset stock_decremented_at if we successfully synced items
    IF v_items_synced THEN
       RAISE NOTICE 'Items synced. Resetting stock flags to retry decrement.';
       
       UPDATE orders 
       SET stock_decremented_at = NULL 
       WHERE id = v_cart.order_id;
       
       -- Note: We do NOT rely on trigger to re-run apply_paid_effects automatically here
       -- We should manually call it or depend on the next update.
       -- But clearing the flag allows the RPC to run again if called.
       
       -- Force re-calculation by calling the RPC directly
       PERFORM apply_paid_effects(v_cart.order_id);
    ELSE
       RAISE WARNING 'Failed to sync items for order %', v_cart.order_id;
    END IF;
  END LOOP;
END $$;
