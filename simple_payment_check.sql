-- Query simplificada para verificar o status do pagamento

-- 1. Informações do live_cart
SELECT 
  'live_cart' as tipo,
  id,
  status,
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
  customer_name,
  total,
  created_at,
  paid_at
FROM orders
WHERE live_cart_id = '8b4b1858-d7e7-4e1a-8ca9-9f8bb34d17d0';

-- 3. Verifica se tem registro de payment com esse mp_payment_id
SELECT 
  'payment' as tipo,
  id,
  mp_payment_id,
  status,
  status_detail,
  transaction_amount,
  created_at
FROM payments
WHERE mp_payment_id = '145529380910';
