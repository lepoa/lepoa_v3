-- 🚨 SCRIPT DE LIMPEZA GERAL ("DIA 1") 🚨
-- Este script apaga TODO o histórico de vendas, produtos e lives.
-- MANTÉM: Configurações do sistema e logins de usuários (apenas reseta os dados deles).

-- 1. FAXINA NAS VENDAS (Começa pelos itens para não dar erro de vínculo)
DELETE FROM order_items;      -- Itens dos pedidos
DELETE FROM orders;           -- Pedidos finalizados
DELETE FROM live_cart_items;  -- Itens dos carrinhos de live
DELETE FROM live_carts;       -- Carrinhos de live

-- 2. FAXINA NAS LIVES
DELETE FROM live_comments;    -- Comentários (se houver)
DELETE FROM live_events;      -- As lives em si

-- 3. FAXINA NO CATÁLOGO
DELETE FROM product_images;       -- Fotos dos produtos
DELETE FROM product_variations;   -- Tamanhos/Cores
DELETE FROM products;             -- Produtos
DELETE FROM coupons;              -- Cupons de desconto

-- 4. FAXINA NA GAMIFICAÇÃO (Zerar pontos)
DELETE FROM mission_attempts;     -- Histórico de tentativas
DELETE FROM mission_progress;     -- Progresso das missões

-- 5. RESETAR PERFIS DE USUÁRIOS
-- Não deletamos a conta para não bloquear o email no sistema de Autenticação.
-- Apenas zeramos os dados para parecer um usuário novo.
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
-- (Preserva os dados do Admin para você não perder seu nível de teste, se tiver)

-- FIM DA LIMPEZA
-- Agora o site está pronto para lançar!
