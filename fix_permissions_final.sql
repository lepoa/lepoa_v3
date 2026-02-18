-- DESBLOQUEIO GERAL DE VISUALIZAÇÃO DOS CARRINHOS
-- Isso garante que as permissões de segurança (RLS) não escondam o pedido de você.

-- 1. Garante que RLS está ligado (segurança base)
ALTER TABLE live_carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_cart_items ENABLE ROW LEVEL SECURITY;

-- 2. Cria permissão PÚBLICA de LEITURA (Resolve o problema de não aparecer)
-- (Removemos políticas antigas para evitar conflito)
DROP POLICY IF EXISTS "Public Access Carts" ON live_carts;
DROP POLICY IF EXISTS "Public Access Items" ON live_cart_items;
DROP POLICY IF EXISTS "Users can see own carts" ON live_carts; -- Limpeza

-- Política: Todo mundo pode CONSULTAR carrinhos (Necessário para Checkout e Meus Pedidos funcionarem sem travas)
CREATE POLICY "Public Access Carts" ON live_carts FOR SELECT USING (true);
CREATE POLICY "Public Access Items" ON live_cart_items FOR SELECT USING (true);

-- (Opcional) Permissão extra para o dono poder editar se precisar no futuro
DROP POLICY IF EXISTS "Owner Edit Access" ON live_carts;
CREATE POLICY "Owner Edit Access" ON live_carts FOR ALL USING (auth.uid() = user_id);
