-- 🚨 SCRIPT DE LIMPEZA GERAL ("DIA 1") - VERSÃO CORRIGIDA 🚨
-- Resolve o problema de vínculo circular (Carrinho <-> Pedido)

-- 1. QUEBRAR VÍNCULOS CIRCULARES
-- Primeiro, desconectamos os pedidos dos carrinhos para evitar travas de exclusão
UPDATE live_carts SET order_id = NULL;

-- 2. FAXINA NAS VENDAS
DELETE FROM order_items;      -- Itens dos pedidos
DELETE FROM orders;           -- Pedidos finalizados (AGORA FUNCIONA PORQUE ORDER_ID JÁ É NULL NO LIVE_CARTS)
DELETE FROM live_cart_items;  -- Itens dos carrinhos de live
DELETE FROM live_carts;       -- Carrinhos de live

-- 3. FAXINA NAS LIVES
DELETE FROM live_comments;    -- Comentários
DELETE FROM live_events;      -- As lives em si

-- 4. FAXINA NO CATÁLOGO
DELETE FROM product_images;       -- Fotos dos produtos
DELETE FROM product_variations;   -- Tamanhos/Cores
DELETE FROM products;             -- Produtos
DELETE FROM coupons;              -- Cupons de desconto

-- 5. FAXINA NA GAMIFICAÇÃO
DELETE FROM mission_attempts;     -- Histórico de tentativas
DELETE FROM mission_progress;     -- Progresso das missões

-- 6. RESETAR PERFIS DE USUÁRIOS
-- Preserva o Admin, mas reseta todos os outros usuários para nível 1
UPDATE profiles
SET 
  quiz_points = 0,
  quiz_level = 1,
  completed_missions = '{}',
  last_mission_id = NULL,
  last_mission_completed_at = NULL,
  style_title = NULL
WHERE user_id NOT IN (
  SELECT user_id FROM user_roles WHERE role = 'admin'
);

-- MENSAGEM FINAL
-- Agora o banco está limpo! Pode começar a vender. ✨
