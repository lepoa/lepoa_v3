-- Função RPC para permitir que o usuário (mesmo anônimo/guest) salve o link de pagamento no carrinho
-- Necessária para contornar RLS restritivo na tabela live_carts durante o checkout
CREATE OR REPLACE FUNCTION set_live_cart_preference(
    p_cart_id UUID,
    p_preference_id TEXT,
    p_checkout_url TEXT,
    p_total NUMERIC DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE live_carts
    SET mp_preference_id = p_preference_id,
        mp_checkout_url = p_checkout_url,
        -- Atualiza o total se fornecido (com frete calculado no backend)
        total = COALESCE(p_total, total),
        -- Define status como aguardando pagamento para iniciar o countdown de expiração
        status = CASE WHEN status = 'aberto' THEN 'aguardando_pagamento' ELSE status END,
        updated_at = NOW()
    WHERE id = p_cart_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
