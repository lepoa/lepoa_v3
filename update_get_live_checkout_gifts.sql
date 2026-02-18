-- Atualiza get_live_checkout para incluir brindes na lista de itens
CREATE OR REPLACE FUNCTION public.get_live_checkout(p_cart_id UUID, p_token UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cart RECORD;
  v_items JSONB;
  v_gifts JSONB;
  v_customer RECORD;
  v_identity RECORD;
  v_result JSONB;
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
  
  -- Get regular items
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', lci.id,
    'product_name', COALESCE(pc.name, 'Produto'),
    'product_image', pc.image_url,
    'color', (lci.variante->>'cor'),
    'size', (lci.variante->>'tamanho'),
    'quantity', lci.qtd,
    'unit_price', lci.preco_unitario,
    'status', lci.status,
    'is_gift', false
  )), '[]'::jsonb)
  INTO v_items
  FROM live_cart_items lci
  LEFT JOIN product_catalog pc ON pc.id = lci.product_id
  WHERE lci.live_cart_id = p_cart_id
    AND lci.status IN ('reservado', 'confirmado', 'expirado');

  -- Get gift items
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', og.id,
    'product_name', COALESCE(g.name, 'Brinde'),
    'product_image', g.image_url,
    'color', 'Único', 
    'size', 'Único',
    'quantity', og.qty,
    'unit_price', 0,
    'status', og.status,
    'is_gift', true,
    'gift_id', g.id
  )), '[]'::jsonb)
  INTO v_gifts
  FROM order_gifts og
  LEFT JOIN gifts g ON g.id = og.gift_id
  WHERE og.live_cart_id = p_cart_id
    AND og.status != 'removed';
  
  -- Check instagram identity for auto-fill
  IF v_customer.instagram_handle IS NOT NULL THEN
    SELECT * INTO v_identity
    FROM instagram_identities
    WHERE instagram_handle_normalized = lower(trim(replace(v_customer.instagram_handle, '@', '')));
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
    'items', v_items || v_gifts, -- Merge arrays
    'known_phone', v_identity.phone,
    'known_customer_id', v_identity.customer_id,
    'known_email', v_identity.email
  );
  
  RETURN v_result;
END;
$$;
