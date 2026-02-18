-- 🚨 SCRIPT DE LIMPEZA TOTAL ("DIA 1" - VERSÃO DEFINITIVA V2) 🚨
-- Apaga TUDO para deixar o site como novo.

-- 1. DESATIVAR TRAVAS (Para apagar sem erros)
SET session_replication_role = 'replica';

-- 2. LIMPAR VENDAS E LIVES (Geral - Tabelas que existem)
TRUNCATE TABLE order_items, orders CASCADE;
TRUNCATE TABLE live_cart_items, live_carts, live_cart_status_history CASCADE;
TRUNCATE TABLE live_events, live_pendencias, live_charge_logs CASCADE;
TRUNCATE TABLE live_customers, live_raffles, live_waitlist, live_products CASCADE;
TRUNCATE TABLE payments, mp_payment_events CASCADE;
TRUNCATE TABLE coupon_uses, coupons CASCADE; -- Zerando Cupons também

-- 3. LIMPAR PRODUTOS E ESTOQUE
-- Cuidado: Isso apaga o cadastro dos produtos!
TRUNCATE TABLE product_catalog CASCADE;
TRUNCATE TABLE product_available_stock, public_product_stock CASCADE;
TRUNCATE TABLE customer_catalogs, customer_favorites, customer_product_suggestions CASCADE;
TRUNCATE TABLE inventory_imports, inventory_movements CASCADE;
TRUNCATE TABLE gift_rules, gifts, order_gifts CASCADE; -- Apaga as regras de brindes e brindes

-- 4. LIMPAR CLIENTES E DADOS PESSOAIS
-- Mantendo a tabela 'customers' vazia
TRUNCATE TABLE customers CASCADE;
TRUNCATE TABLE customer_addresses CASCADE;
TRUNCATE TABLE customer_loyalty CASCADE;
TRUNCATE TABLE customer_inspiration_photos CASCADE;
TRUNCATE TABLE instagram_identities CASCADE; -- Limpa vínculo com Instagram

-- 5. LIMPAR GAMIFICAÇÃO E QUIZ (Zerar resultados, manter perguntas)
TRUNCATE TABLE quiz_leads, quiz_responses CASCADE;
TRUNCATE TABLE mission_attempts, mission_responses, missions_log CASCADE;
TRUNCATE TABLE point_transactions, reward_redemptions CASCADE;
TRUNCATE TABLE recommendations CASCADE;
TRUNCATE TABLE print_requests CASCADE;

-- 6. RESETAR PERFIS DE USUÁRIOS (Zerar nível e pontos)
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

-- 7. REATIVAR TRAVAS (Segurança)
SET session_replication_role = 'origin';

-- PRONTO! BANCO ZERADO COMPLETAMENTE.
