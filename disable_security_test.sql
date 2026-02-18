-- TESTE DE DESATIVAÇÃO DE SEGURANÇA
-- Desliga a verificação de permissões para ter certeza se é isso que está bloqueando.

ALTER TABLE live_carts DISABLE ROW LEVEL SECURITY;
ALTER TABLE live_cart_items DISABLE ROW LEVEL SECURITY;

-- Se o pedido aparecer depois disso, era permissão mesmo!
-- Depois a gente liga de volta com a regra certa.
