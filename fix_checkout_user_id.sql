-- 1. Remove a função antiga para não dar conflito (opcional, mas bom pra limpeza)
DROP FUNCTION IF EXISTS public.save_live_checkout_details(uuid, uuid, text, text, text, text, text, jsonb, numeric, text, integer, text);

-- 2. Cria a nova versão que RECEBE O ID do usuário (p_user_id)
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
  p_customer_notes TEXT DEFAULT NULL,
  p_user_id UUID DEFAULT NULL -- <--- NOVO PARÂMETRO
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cart RECORD;
  v_total NUMERIC;
  v_final_user_id UUID;
BEGIN
  -- Tenta usar o ID passado; se não vier, tenta pegar da autenticação; se não, fica null
  v_final_user_id := COALESCE(p_user_id, auth.uid());

  -- Valida carrinho
  SELECT * INTO v_cart FROM live_carts WHERE id = p_cart_id AND public_token = p_token;
  
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'Erro: Sacola não encontrada'); END IF;
  
  IF v_cart.status IN ('pago', 'cancelado', 'enviado', 'entregue') THEN 
    RETURN jsonb_build_object('error', 'Sacola já finalizada'); 
  END IF;
  
  v_total := v_cart.subtotal + COALESCE(p_shipping_fee, 0);
  
  -- Atualiza o carrinho salvando o DONO (user_id)
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
    updated_at = now(),
    user_id = v_final_user_id  -- <--- Salva o ID garantido
  WHERE id = p_cart_id;
  
  -- Atualiza WhatsApp e Nome do cliente
  UPDATE live_customers SET
    nome = CASE WHEN p_name IS NOT NULL AND length(p_name) > 0 THEN p_name ELSE nome END,
    whatsapp = CASE WHEN p_phone IS NOT NULL AND length(p_phone) > 6 THEN p_phone ELSE whatsapp END,
    updated_at = now()
  WHERE id = v_cart.live_customer_id;
  
  RETURN jsonb_build_object('success', true, 'total', v_total);
END;
$$;
