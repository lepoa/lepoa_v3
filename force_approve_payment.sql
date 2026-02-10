
-- Substitua 'SEU_PAYMENT_ID_DO_MP' pelo ID que você pegar no extrato do Mercado Pago
-- Substitua 'SEU_ORDER_ID' pelo ID do pedido (b07ec134-7c1d-4009-8e5e-7392d8d6b8ac)
-- Substitua '12.00' pelo valor real pago (12.00)

BEGIN;

-- 1. Cria o registro de pagamento (se não existir)
INSERT INTO payments (
  order_id,
  provider,
  mp_payment_id,
  status,
  amount_total,
  installments,
  payer_email,
  updated_at
) VALUES (
  'b07ec134-7c1d-4009-8e5e-7392d8d6b8ac', -- Order ID fixo do último pedido
  'mercadopago',
  'ID_DO_PAGAMENTO_MP', -- COLOCAR O ID AQUI SE TIVER
  'approved',
  12.00,
  1,
  'comercial@lepoa.com.br', -- Email provisório
  NOW()
)
ON CONFLICT (order_id, provider) DO UPDATE SET
  status = 'approved',
  mp_payment_id = EXCLUDED.mp_payment_id,
  amount_total = EXCLUDED.amount_total,
  updated_at = NOW();

-- 2. Atualiza o pedido para PAGO
UPDATE orders
SET 
  status = 'pago',
  payment_status = 'approved',
  paid_at = NOW(),
  updated_at = NOW()
WHERE id = 'b07ec134-7c1d-4009-8e5e-7392d8d6b8ac'; -- Order ID fixo

-- 3. Chama a função de baixar estoque (efeitos colaterais)
SELECT apply_paid_effects(
  'b07ec134-7c1d-4009-8e5e-7392d8d6b8ac',
  12.00,
  NOW(),
  'mercado_pago'
);

COMMIT;
