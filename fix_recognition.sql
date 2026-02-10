-- 1. Populate identities from existing paid carts (Retroactive Fix)
INSERT INTO public.instagram_identities (
  instagram_handle_normalized, 
  instagram_handle_raw, 
  phone, 
  last_order_id, 
  last_paid_at
)
SELECT DISTINCT ON (lower(trim(replace(c.instagram_handle, '@', ''))))
  lower(trim(replace(c.instagram_handle, '@', ''))),
  c.instagram_handle,
  regexp_replace(c.whatsapp, '\D', '', 'g'), -- Normalize phone
  o.id,
  o.paid_at
FROM live_carts lc
JOIN live_customers c ON lc.live_customer_id = c.id
JOIN orders o ON o.live_cart_id = lc.id
WHERE lc.status = 'pago' 
  AND c.instagram_handle IS NOT NULL
  AND c.whatsapp IS NOT NULL
ORDER BY lower(trim(replace(c.instagram_handle, '@', ''))), o.paid_at DESC
ON CONFLICT (instagram_handle_normalized) 
DO UPDATE SET
  phone = EXCLUDED.phone,
  last_order_id = EXCLUDED.last_order_id,
  last_paid_at = EXCLUDED.last_paid_at;


-- 2. Update get_live_checkout to return email (using last payment info)
CREATE OR REPLACE FUNCTION public.get_live_checkout(p_cart_id UUID, p_token UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cart RECORD;
  v_items JSONB;
  v_customer RECORD;
  v_identity RECORD;
  v_result JSONB;
  v_known_email TEXT;
BEGIN
  -- Validate cart + token
  SELECT lc.*, le.titulo as event_title
  INTO v_cart
  FROM live_carts lc
  JOIN live_events le ON le.id = lc.live_event_id
  WHERE lc.id = p_cart_id AND lc.public_token = p_token;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Sacola não encontrada ou token inválido');
  END IF;
  
  IF v_cart.status = 'cancelado' THEN
    RETURN jsonb_build_object('error', 'Esta sacola foi cancelada');
  END IF;
  
  -- Get customer info
  SELECT * INTO v_customer FROM live_customers WHERE id = v_cart.live_customer_id;
  
  -- Get items
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', lci.id,
    'product_name', COALESCE(pc.name, 'Produto'),
    'product_image', pc.image_url,
    'color', (lci.variante->>'cor'),
    'size', (lci.variante->>'tamanho'),
    'quantity', lci.qtd,
    'unit_price', lci.preco_unitario,
    'status', lci.status
  )), '[]'::jsonb)
  INTO v_items
  FROM live_cart_items lci
  LEFT JOIN product_catalog pc ON pc.id = lci.product_id
  WHERE lci.live_cart_id = p_cart_id
    AND lci.status IN ('reservado', 'confirmado', 'expirado');
  
  -- Check instagram identity for auto-fill
  IF v_customer.instagram_handle IS NOT NULL THEN
    SELECT * INTO v_identity
    FROM instagram_identities
    WHERE instagram_handle_normalized = lower(trim(replace(v_customer.instagram_handle, '@', '')));

    IF FOUND THEN
        -- Try to find email from the last payment of this identity
        IF v_identity.last_order_id IS NOT NULL THEN
             SELECT payer_email INTO v_known_email 
             FROM payments 
             WHERE order_id = v_identity.last_order_id 
             ORDER BY created_at DESC 
             LIMIT 1;
        END IF;
    END IF;
  END IF;
  
  v_result := jsonb_build_object(
    'id', v_cart.id,
    'status', v_cart.status,
    'bag_number', v_cart.bag_number,
    'subtotal', v_cart.subtotal,
    'frete', v_cart.frete,
    'total', v_cart.total,
    'coupon_discount', COALESCE(v_cart.coupon_discount, 0),
    'delivery_method', v_cart.delivery_method,
    'shipping_address_snapshot', v_cart.shipping_address_snapshot,
    'mp_checkout_url', v_cart.mp_checkout_url,
    'event_title', v_cart.event_title,
    'created_at', v_cart.created_at,
    'instagram_handle', v_customer.instagram_handle,
    'customer_name', v_customer.nome,
    'customer_whatsapp', v_customer.whatsapp,
    'items', v_items,
    'known_phone', v_identity.phone,
    'known_customer_id', v_identity.customer_id,
    'known_email', v_known_email
  );
  
  RETURN v_result;
END;
$$;
