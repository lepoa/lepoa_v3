
-- ATUALIZAÇÃO DA FUNÇÃO GET_LIVE_CHECKOUT
-- Agora ela busca dados históricos (Endereço, Nome, CPF, Email) do último pedido do cliente
-- Baseado no reconhecimento via Instagram Handle

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
  v_last_order RECORD;
  v_result JSONB;
  v_address_snapshot JSONB;
  v_final_name TEXT;
  v_final_email TEXT;
BEGIN
  -- 1. Buscar Carrinho e Evento
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
  
  -- 2. Buscar Cliente da Live
  SELECT * INTO v_customer FROM live_customers WHERE id = v_cart.live_customer_id;
  
  -- 3. Buscar Itens
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
  
  -- 4. INTELIGÊNCIA: Buscar identidade e histórico
  v_address_snapshot := v_cart.shipping_address_snapshot;
  v_final_name := v_customer.nome;
  v_final_email := NULL;

  IF v_customer.instagram_handle IS NOT NULL THEN
    -- Busca identidade pelo handle normalizado
    SELECT * INTO v_identity
    FROM instagram_identities
    WHERE instagram_handle_normalized = lower(trim(replace(v_customer.instagram_handle, '@', '')));
    
    -- Se encontrou identidade e tem um último pedido, busca os dados desse pedido
    IF FOUND AND v_identity.last_order_id IS NOT NULL THEN
       SELECT address_snapshot, customer_name, payer_email 
       INTO v_last_order
       FROM orders 
       LEFT JOIN payments p ON p.order_id = orders.id
       WHERE orders.id = v_identity.last_order_id;
       
       -- Se o carrinho atual não tem endereço, usa o do último pedido
       IF v_address_snapshot IS NULL OR v_address_snapshot = 'null'::jsonb THEN
          v_address_snapshot := v_last_order.address_snapshot;
       END IF;

       -- Se o cliente atual não tem nome completo, usa o do último pedido
       IF v_final_name IS NULL OR v_final_name = '' THEN
          v_final_name := v_last_order.customer_name;
       END IF;

       -- Tenta recuperar e-mail do pagamento anterior
       v_final_email := v_last_order.payer_email;
    END IF;
  END IF;
  
  -- 5. Montar Resultado
  v_result := jsonb_build_object(
    'id', v_cart.id,
    'status', v_cart.status,
    'bag_number', v_cart.bag_number,
    'subtotal', v_cart.subtotal,
    'frete', v_cart.frete,
    'total', v_cart.total,
    'coupon_discount', COALESCE(v_cart.coupon_discount, 0),
    'delivery_method', v_cart.delivery_method,
    'shipping_address_snapshot', v_address_snapshot, -- Aqui vai o endereço histórico se existir
    'mp_checkout_url', v_cart.mp_checkout_url,
    'event_title', v_cart.event_title,
    'created_at', v_cart.created_at,
    'instagram_handle', v_customer.instagram_handle,
    'customer_name', v_final_name,
    'customer_whatsapp', v_customer.whatsapp,
    'items', v_items,
    'known_phone', v_identity.phone,
    'known_email', v_final_email, -- Email recuperado
    'known_customer_id', v_identity.customer_id
  );
  
  RETURN v_result;
END;
$$;
