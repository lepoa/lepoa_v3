-- PLANO D: LIMPEZA CIRÚRGICA (Só o que confirmamos que existe)

SET session_replication_role = 'replica';

-- 1. LIMPAR VENDAS E LIVES (Isso com certeza existe)
TRUNCATE TABLE orders CASCADE;
TRUNCATE TABLE live_carts CASCADE;
TRUNCATE TABLE live_events CASCADE;

-- 2. LIMPAR CUPONS (Se der erro aqui, remova esta linha)
TRUNCATE TABLE coupons CASCADE;

-- 3. LIMPAR GAMIFICAÇÃO (Tentativas de Missão)
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

-- PRONTO! BANCO ZERADO (Sem mexer em produtos).
