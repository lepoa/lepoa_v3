DO $$
DECLARE
    r RECORD;
    v_item_count INT;
    v_update_count INT;
BEGIN
    RAISE NOTICE 'Starting broad fix for live orders (Items + Delivery Method)...';

    -- 1. Sync Delivery Method & Details from Live Carts to Orders
    -- This fixes the issue where "Retirada" or other methods were chosen but not synced to the order header
    UPDATE orders o
    SET 
        delivery_method = COALESCE(lc.delivery_method, o.delivery_method),
        shipping_fee = COALESCE(lc.frete, o.shipping_fee),
        address_snapshot = COALESCE(lc.shipping_address_snapshot, o.address_snapshot),
        customer_phone = COALESCE(NULLIF(lc.live_customer_phone, ''), o.customer_phone), -- Helper valid selection
        updated_at = NOW()
    FROM (
        SELECT 
            lc.id, 
            lc.delivery_method, 
            lc.frete, 
            lc.shipping_address_snapshot,
            c.whatsapp as live_customer_phone
        FROM live_carts lc
        LEFT JOIN live_customers c ON c.id = lc.live_customer_id
    ) lc
    WHERE o.live_cart_id = lc.id
      AND (
          o.delivery_method IS DISTINCT FROM lc.delivery_method
          OR o.shipping_fee IS DISTINCT FROM lc.frete
      );
      
    GET DIAGNOSTICS v_update_count = ROW_COUNT;
    RAISE NOTICE 'Synced delivery details for % orders', v_update_count;

    -- 2. Backfill missing items (Original Logic)
    FOR r IN 
        SELECT o.id, o.live_cart_id, o.customer_name
        FROM public.orders o
        WHERE o.source = 'live'
          AND o.live_cart_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM public.order_items oi WHERE oi.order_id = o.id
          )
    LOOP
        RAISE NOTICE 'Fixing Items for Order % (%)', r.id, r.customer_name;

        INSERT INTO public.order_items (
            order_id,
            product_id,
            product_name,
            product_price,
            quantity,
            size,
            color,
            image_url,
            created_at
        )
        SELECT 
            r.id,
            lci.product_id,
            p.name,
            lci.preco_unitario,
            lci.qtd,
            lci.variante->>'tamanho',
            p.color,
            p.image_url,
            NOW()
        FROM public.live_cart_items lci
        LEFT JOIN public.product_catalog p ON p.id = lci.product_id
        WHERE lci.live_cart_id = r.live_cart_id
          AND lci.status IN ('reservado', 'confirmado')
        ON CONFLICT DO NOTHING;
          
        GET DIAGNOSTICS v_item_count = ROW_COUNT;
        RAISE NOTICE ' -> Added % items', v_item_count;
        
    END LOOP;
    
    RAISE NOTICE 'Fix complete.';
END $$;
