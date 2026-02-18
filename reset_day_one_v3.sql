-- PLANO C: LIMPEZA INTELIGENTE (Via CASCADE)
-- Apagamos apenas os "Pais", e o sistema limpa os "Filhos" automaticamente.

SET session_replication_role = 'replica';

-- 1. LIMPAR VENDAS E LIVES
TRUNCATE TABLE orders CASCADE;           -- Leva junto order_items
TRUNCATE TABLE live_carts CASCADE;       -- Leva junto live_cart_items
TRUNCATE TABLE live_events CASCADE;      -- Leva junto live_comments (se existir)

-- 2. LIMPAR CATÁLOGO
TRUNCATE TABLE products CASCADE;         -- Leva junto variações e imagens
TRUNCATE TABLE coupons CASCADE;

-- 3. LIMPAR GAMIFICAÇÃO
-- (Usamos IF EXISTS mentalmente aqui, mas o TRUNCATE direto é mais robusto com CASCADE nas tabelas pai)
TRUNCATE TABLE mission_attempts CASCADE;

-- 4. RESETAR PONTOS DOS PERFIS
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

SET session_replication_role = 'origin';

-- PRONTO! BANCO ZERADO.
