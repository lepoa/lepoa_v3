-- =====================================================
-- FIX: upsert_live_cart_item should reset status and quantity if item was previously cancelled/removed
-- =====================================================

CREATE OR REPLACE FUNCTION upsert_live_cart_item(
  p_live_cart_id uuid,
  p_product_id uuid,
  p_variante jsonb,
  p_qtd integer,
  p_preco_unitario numeric,
  p_expiracao_reserva_em timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_id uuid;
  v_existing_qtd integer;
  v_existing_status text;
  v_new_qtd integer;
  v_tamanho text;
  v_result_id uuid;
  v_action text;
BEGIN
  -- Extract tamanho from variante
  v_tamanho := p_variante->>'tamanho';
  
  -- Acquire advisory lock to serialize access for this specific item
  PERFORM pg_advisory_xact_lock(
    hashtext('live_cart_item_' || p_live_cart_id::text || '_' || p_product_id::text || '_' || COALESCE(v_tamanho, 'null'))
  );
  
  -- Check if item already exists in this cart
  SELECT id, qtd, status INTO v_existing_id, v_existing_qtd, v_existing_status
  FROM live_cart_items
  WHERE live_cart_id = p_live_cart_id
    AND product_id = p_product_id
    AND (variante->>'tamanho') = v_tamanho
  FOR UPDATE;
  
  IF v_existing_id IS NOT NULL THEN
    -- Item exists: 
    -- If it was cancelled, removed or expired, START FRESH with new quantity
    -- Otherwise ADD to existing quantity
    IF v_existing_status IN ('cancelado', 'removido', 'expirado') THEN
        v_new_qtd := p_qtd;
        v_action := 'reactivated';
    ELSE
        v_new_qtd := v_existing_qtd + p_qtd;
        v_action := 'updated';
    END IF;
    
    UPDATE live_cart_items
    SET 
      qtd = v_new_qtd,
      status = 'reservado', -- Reset to active status
      separation_status = 'em_separacao', -- Reset separation flow
      separation_notes = NULL, -- Clear any "don't ship" notes
      -- Only update expiration if provided
      expiracao_reserva_em = COALESCE(p_expiracao_reserva_em, expiracao_reserva_em),
      updated_at = now()
    WHERE id = v_existing_id;
    
    v_result_id := v_existing_id;

    -- Also check if we need to reactivate the cart itself
    UPDATE live_carts
    SET 
        status = CASE 
            WHEN status IN ('cancelado', 'expirado') THEN 'aguardando_pagamento' 
            ELSE status 
        END,
        separation_status = CASE 
            WHEN separation_status = 'cancelado' THEN 'pendente' 
            ELSE separation_status 
        END
    WHERE id = p_live_cart_id;

  ELSE
    -- Item does not exist: INSERT new record
    INSERT INTO live_cart_items (
      live_cart_id,
      product_id,
      variante,
      qtd,
      preco_unitario,
      status,
      separation_status,
      reservado_em,
      expiracao_reserva_em
    )
    VALUES (
      p_live_cart_id,
      p_product_id,
      p_variante,
      p_qtd,
      p_preco_unitario,
      'reservado',
      'em_separacao',
      now(),
      p_expiracao_reserva_em
    )
    RETURNING id INTO v_result_id;
    
    v_new_qtd := p_qtd;
    v_action := 'inserted';
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'action', v_action,
    'item_id', v_result_id,
    'qtd', v_new_qtd,
    'previous_qtd', COALESCE(v_existing_qtd, 0)
  );
END;
$$;

-- Retroactive fix for the user laistmelo (if we can identify the cart)
-- We'll look for any item that is 'cancelado' but has been updated AFTER its cancellation log or just recently
-- Actually, the user's specific case has status 'cancelado' and qtd 2.
-- If we want to fix it to 1 and 'reservado':
UPDATE live_cart_items
SET status = 'reservado', 
    separation_status = 'em_separacao',
    qtd = 1,
    separation_notes = NULL
WHERE id = 'e8c58515-9bcb-418b-bf98-f10ced947fc6' -- This is the ID I found in my query
  AND status = 'cancelado';

-- And reactivate the cart if it's currently cancelled
UPDATE live_carts
SET status = 'aguardando_pagamento',
    separation_status = 'atencao' -- or pendente? If it has items, SeparationByBag will see them.
WHERE id = 'ae700f7a-b3ce-484b-9d1d-9d409f93b22e'
  AND status = 'cancelado';
