-- Verifica os logs de pagamento e webhook para esse pedido específico

-- 1. Busca o live_cart_id e payment_id desse pedido
SELECT 
  'order_info' as tipo,
  o.id as order_id,
  o.live_cart_id,
  o.status as order_status,
  o.payment_id,
  lc.status as cart_status,
  lc.mp_payment_id,
  lc.mp_checkout_url
FROM orders o
LEFT JOIN live_carts lc ON o.live_cart_id = lc.id
WHERE o.id = (
  SELECT id FROM orders 
  WHERE customer_phone = '5562982691262' 
  ORDER BY created_at DESC 
  LIMIT 1
);

-- 2. Verifica se existe registro na tabela payments
SELECT 
  'payment_record' as tipo,
  p.id,
  p.order_id,
  p.mp_payment_id,
  p.status,
  p.status_detail,
  p.payer_email,
  p.created_at,
  p.updated_at
FROM payments p
WHERE p.order_id = (
  SELECT id FROM orders 
  WHERE customer_phone = '5562982691262' 
  ORDER BY created_at DESC 
  LIMIT 1
);

-- 3. Verifica o live_cart
SELECT 
  'live_cart_info' as tipo,
  lc.id,
  lc.status,
  lc.mp_payment_id,
  lc.total,
  lc.created_at,
  lc.updated_at
FROM live_carts lc
WHERE lc.id = (
  SELECT live_cart_id FROM orders 
  WHERE customer_phone = '5562982691262' 
  ORDER BY created_at DESC 
  LIMIT 1
);
