-- ============================================
-- FIX: Complete rewrite of trigger_sync_live_cart_to_orders
-- 
-- PROBLEMS FOUND:
-- 1. Multiple migrations redefined this function with different column names
-- 2. UPDATE path was missing delivery_method, address_snapshot, user_id sync
-- 3. INSERT path was only for 'em_confirmacao'/'aguardando_pagamento'/'pago' 
--    but should also handle 'aberto' status
-- 4. customer_name/customer_phone/customer_address never synced on UPDATE
-- 5. EXCEPTION handler silently swallowed all errors
--
-- This version uses verified column names from the Supabase generated types.
-- ============================================

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
  -- PROTECTION 1: Session flag to prevent re-entry (ping-pong)
  IF current_setting('app.syncing_order', true) = 'true' THEN
    RETURN NEW;
  END IF;

  -- Only process relevant changes (skip if nothing meaningful changed)
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

  -- Set flag to prevent order trigger from calling us back
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

    -- Map live_cart status to order status
    -- CRITICAL: 'aberto' maps to 'aguardando_pagamento' so it appears in Admin
    v_order_status := CASE NEW.status::text
      WHEN 'aberto' THEN 'aguardando_pagamento'
      WHEN 'em_confirmacao' THEN 'aguardando_pagamento'
      WHEN 'aguardando_pagamento' THEN 'aguardando_pagamento'
      WHEN 'pago' THEN 'pago'
      WHEN 'cancelado' THEN 'cancelado'
      WHEN 'expirado' THEN 'cancelado'
      ELSE 'aguardando_pagamento'
    END;

    -- Build customer name and phone
    v_customer_name := COALESCE(v_live_customer.nome, v_live_customer.instagram_handle, 'Cliente Live');
    v_customer_phone := COALESCE(v_live_customer.whatsapp, '');

    RAISE NOTICE '[sync_trigger] TG_OP=%, cart=%, status=%, customer=%', 
      TG_OP, NEW.id, NEW.status, v_customer_name;

    -- Check if order exists for this live_cart
    SELECT id INTO v_order_id
    FROM orders
    WHERE live_cart_id = NEW.id;

    IF v_order_id IS NOT NULL THEN
      -- ========== UPDATE existing order ==========
      RAISE NOTICE '[sync_trigger] Updating order % for cart %', v_order_id, NEW.id;
      
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
        -- FIX: Sync delivery_method on updates (was missing before!)
        delivery_method = COALESCE(NEW.delivery_method, delivery_method),
        -- FIX: Sync shipping address snapshot
        address_snapshot = COALESCE(NEW.shipping_address_snapshot, address_snapshot),
        -- FIX: Sync user_id  
        user_id = COALESCE(NEW.user_id, user_id),
        -- FIX: Update customer info from live_customer
        customer_name = COALESCE(NULLIF(v_customer_name, 'Cliente Live'), customer_name),
        customer_phone = CASE WHEN v_customer_phone != '' THEN v_customer_phone ELSE customer_phone END,
        updated_at = now()
      WHERE id = v_order_id;
      
    ELSE
      -- ========== CREATE new order ==========
      -- Create for ALL statuses except cancelled/expired
      -- This ensures bags appear in Admin > Pedidos immediately upon creation
      IF NEW.status::text NOT IN ('cancelado', 'expirado') THEN
        -- Find or create customer
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

        RAISE NOTICE '[sync_trigger] Creating order for cart %, customer_id=%', NEW.id, v_customer_id;

        -- Create order with 7-day reservation for live orders
        INSERT INTO orders (
          customer_id,
          customer_name,
          customer_phone,
          customer_address,
          status,
          total,
          subtotal,
          shipping_fee,
          coupon_discount,
          source,
          live_cart_id,
          live_event_id,
          live_bag_number,
          paid_at,
          gateway,
          delivery_method,
          address_snapshot,
          tracking_code,
          me_label_url,
          me_shipment_id,
          user_id,
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
          now() + (COALESCE(v_live_event.reservation_expiry_minutes, 10080) || ' minutes')::interval
        )
        RETURNING id INTO v_order_id;

        RAISE NOTICE '[sync_trigger] Created order % for cart %', v_order_id, NEW.id;

        -- Update live_cart with order_id reference
        UPDATE live_carts SET order_id = v_order_id WHERE id = NEW.id;

        -- Ensure order items are synced
        PERFORM ensure_order_items_for_live_order(v_order_id);
      END IF;
    END IF;

  EXCEPTION WHEN OTHERS THEN
    -- LOG THE ERROR EXPLICITLY so we can debug!
    RAISE WARNING '[sync_trigger] ERROR for cart %: % (SQLSTATE: %)', NEW.id, SQLERRM, SQLSTATE;
  END;

  -- Clear the flag
  PERFORM set_config('app.syncing_live_cart', 'false', true);

  RETURN NEW;
END;
$$;

-- ============================================
-- Also ensure the trigger is AFTER INSERT OR UPDATE (not just UPDATE)
-- ============================================
DROP TRIGGER IF EXISTS on_live_cart_sync_to_orders ON public.live_carts;
CREATE TRIGGER on_live_cart_sync_to_orders
  AFTER INSERT OR UPDATE ON public.live_carts
  FOR EACH ROW
  EXECUTE FUNCTION trigger_sync_live_cart_to_orders();

-- ============================================
-- FIX: ensure_order_items_for_live_order uses wrong syntax for image_url
-- p.images->0->>'url' fails because images is text[], not jsonb
-- The correct column is p.image_url
-- ============================================
CREATE OR REPLACE FUNCTION ensure_order_items_for_live_order(p_order_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_live_cart_id uuid;
  v_items_created integer := 0;
  v_item RECORD;
BEGIN
  -- Get live_cart_id from order
  SELECT live_cart_id INTO v_live_cart_id
  FROM orders
  WHERE id = p_order_id;
  
  IF v_live_cart_id IS NULL THEN
    RETURN false;
  END IF;
  
  -- Check if order items already exist
  IF EXISTS (SELECT 1 FROM order_items WHERE order_id = p_order_id) THEN
    RETURN true;
  END IF;
  
  -- Copy items from live_cart_items to order_items
  FOR v_item IN
    SELECT 
      lci.product_id,
      lci.variante->>'tamanho' as size,
      lci.variante->>'cor' as color,
      lci.qtd as quantity,
      lci.preco_unitario as price,
      p.name as product_name,
      p.sku as product_sku,
      p.image_url as image_url
    FROM live_cart_items lci
    JOIN product_catalog p ON p.id = lci.product_id
    WHERE lci.live_cart_id = v_live_cart_id
      AND lci.status IN ('reservado', 'confirmado')
  LOOP
    INSERT INTO order_items (
      order_id,
      product_id,
      product_name,
      product_sku,
      product_price,
      size,
      color,
      quantity,
      image_url
    )
    VALUES (
      p_order_id,
      v_item.product_id,
      COALESCE(v_item.product_name, 'Produto'),
      v_item.product_sku,
      v_item.price,
      COALESCE(v_item.size, ''),
      v_item.color,
      v_item.quantity,
      v_item.image_url
    )
    ON CONFLICT DO NOTHING;
    
    v_items_created := v_items_created + 1;
  END LOOP;
  
  RETURN v_items_created > 0;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'ensure_order_items_for_live_order error for order %: %', p_order_id, SQLERRM;
  RETURN false;
END;
$$;

-- ============================================
-- DIAGNOSTIC: Check for the current live carts without orders
-- ============================================
DO $$
DECLARE
  v_missing_count int;
BEGIN
  SELECT COUNT(*) INTO v_missing_count
  FROM live_carts lc
  WHERE lc.order_id IS NULL
    AND lc.status NOT IN ('cancelado', 'expirado');
  
  IF v_missing_count > 0 THEN
    RAISE NOTICE 'Found % live carts without orders. These will be synced now.', v_missing_count;
  ELSE
    RAISE NOTICE 'All live carts have corresponding orders.';
  END IF;
END $$;

-- ============================================
-- BACKFILL: Create orders for any live carts that are missing orders
-- ============================================
DO $$
DECLARE
  v_cart RECORD;
  v_customer RECORD;
  v_event RECORD;
  v_order_id uuid;
  v_customer_id uuid;
  v_order_status text;
  v_count int := 0;
BEGIN
  FOR v_cart IN 
    SELECT lc.*, 
           lcust.nome, lcust.instagram_handle, lcust.whatsapp, lcust.client_id
    FROM live_carts lc
    JOIN live_customers lcust ON lcust.id = lc.live_customer_id
    WHERE lc.order_id IS NULL
      AND lc.status NOT IN ('cancelado', 'expirado')
  LOOP
    -- Map status
    v_order_status := CASE v_cart.status::text
      WHEN 'aberto' THEN 'aguardando_pagamento'
      WHEN 'em_confirmacao' THEN 'aguardando_pagamento'
      WHEN 'aguardando_pagamento' THEN 'aguardando_pagamento'
      WHEN 'pago' THEN 'pago'
      ELSE 'aguardando_pagamento'
    END;

    -- Find customer
    v_customer_id := v_cart.client_id;
    IF v_customer_id IS NULL THEN
      SELECT id INTO v_customer_id
      FROM customers
      WHERE (phone = v_cart.whatsapp AND v_cart.whatsapp IS NOT NULL)
         OR (instagram_handle = v_cart.instagram_handle AND v_cart.instagram_handle IS NOT NULL)
      LIMIT 1;
    END IF;

    -- Get event
    SELECT * INTO v_event FROM live_events WHERE id = v_cart.live_event_id;

    -- Create order
    INSERT INTO orders (
      customer_id, customer_name, customer_phone, customer_address,
      status, total, subtotal, shipping_fee, coupon_discount,
      source, live_cart_id, live_event_id, live_bag_number,
      paid_at, gateway, delivery_method, address_snapshot,
      tracking_code, me_label_url, me_shipment_id, user_id,
      reserved_until
    ) VALUES (
      v_customer_id,
      COALESCE(v_cart.nome, v_cart.instagram_handle, 'Cliente Live'),
      COALESCE(v_cart.whatsapp, ''),
      '',
      v_order_status,
      v_cart.total,
      v_cart.subtotal,
      v_cart.frete,
      v_cart.descontos,
      'live',
      v_cart.id,
      v_cart.live_event_id,
      v_cart.bag_number,
      v_cart.paid_at,
      v_cart.paid_method,
      v_cart.delivery_method,
      v_cart.shipping_address_snapshot,
      v_cart.shipping_tracking_code,
      v_cart.me_label_url,
      v_cart.me_shipment_id,
      v_cart.user_id,
      now() + (COALESCE(v_event.reservation_expiry_minutes, 10080) || ' minutes')::interval
    )
    RETURNING id INTO v_order_id;

    -- Link back
    UPDATE live_carts SET order_id = v_order_id WHERE id = v_cart.id;

    -- Sync items
    PERFORM ensure_order_items_for_live_order(v_order_id);

    v_count := v_count + 1;
  END LOOP;

  RAISE NOTICE 'Backfilled % orders for live carts without orders', v_count;
END $$;

