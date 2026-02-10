-- Verifica o ÚLTIMO pedido criado
SELECT 
  id,
  created_at,
  status, 
  payment_status, 
  payment_confirmed_amount,
  total,
  gateway,
  mp_preference_id,
  mp_checkout_url
FROM orders
ORDER BY created_at DESC
LIMIT 1;
