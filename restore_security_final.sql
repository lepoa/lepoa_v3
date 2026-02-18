-- REATIVAR SEGURANÇA (RLS)
-- Garante que ninguém possa deletar ou alterar seus pedidos, apenas ler.

ALTER TABLE live_carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_cart_items ENABLE ROW LEVEL SECURITY;

-- Garante que a política de leitura pública esteja ativa
DROP POLICY IF EXISTS "Public Access Carts" ON live_carts;
CREATE POLICY "Public Access Carts" ON live_carts FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public Access Items" ON live_cart_items;
CREATE POLICY "Public Access Items" ON live_cart_items FOR SELECT USING (true);
