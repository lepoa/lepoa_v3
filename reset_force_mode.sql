-- PLANO B: FORÇAR LIMPEZA (Desativar checagens temporariamente)

-- 1. Desliga checagem de chave estrangeira (Permite apagar sem reclamar de vínculos)
SET session_replication_role = 'replica';

-- 2. APAGA TUDO (Usando TRUNCATE CASCADE que é mais forte e rápido)
TRUNCATE TABLE order_items CASCADE;
TRUNCATE TABLE orders CASCADE;
TRUNCATE TABLE live_cart_items CASCADE;
TRUNCATE TABLE live_carts CASCADE;
TRUNCATE TABLE live_comments CASCADE;
TRUNCATE TABLE live_events CASCADE;
TRUNCATE TABLE product_images CASCADE;
TRUNCATE TABLE product_variations CASCADE;
TRUNCATE TABLE products CASCADE;
TRUNCATE TABLE coupons CASCADE;
TRUNCATE TABLE mission_progress CASCADE;
TRUNCATE TABLE mission_attempts CASCADE;

-- 3. RESETAR PERFIS (Zerar pontos, mantém login)
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

-- 4. Religando a checagem (Segurança)
SET session_replication_role = 'origin';

-- PRONTO! BANCO ZERADO.
