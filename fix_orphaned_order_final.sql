-- CORREÇÃO FINAL: VINCULAR O PEDIDO GERADO AO USUÁRIO
-- O carrinho estava vinculado, mas o pedido gerado (orders) estava órfão.

UPDATE orders
SET user_id = '9cf8793c-19e5-4c81-b7ff-321480715b95' -- ID da Laís
WHERE id = 'abcbe4b1-6625-4486-a367-a72b5f1f4d06'; -- ID do Pedido que estava sem dono
