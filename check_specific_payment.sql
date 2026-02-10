-- Busca informações específicas desse carrinho e pagamento

-- 1. Informações do live_cart
SELECT 
  'live_cart' as tipo,
  id,
  status,
  mp_checkout_url,
  total,
  created_at,
  updated_at
FROM live_carts
WHERE id = '8b4b1858-d7e7-4e1a-8ca9-9f8bb34d17d0';

-- 2. Verifica se criou order
SELECT 
  'order' as tipo,
  id,
  status,
  payment_id,
  customer_name,
  total,
  created_at,
  paid_at
FROM orders
WHERE live_cart_id = '8b4b1858-d7e7-4e1a-8ca9-9f8bb34d17d0';

-- 3. Verifica se tem registro de payment
SELECT 
  'payment' as tipo,
  id,
  mp_payment_id,
  status,
  status_detail,
  transaction_amount,
  created_at,
  updated_at
FROM payments
WHERE order_id IN (
  SELECT id FROM orders WHERE live_cart_id = '8b4b1858-d7e7-4e1a-8ca9-9f8bb34d17d0'
);

-- 4. Busca pelo mp_payment_id do Mercado Pago (só em payments)
SELECT 
  'search_by_mp_id' as tipo,
  id,
  mp_payment_id,
  status,
  status_detail,
  order_id
FROM payments
WHERE mp_payment_id = '145529380910';
