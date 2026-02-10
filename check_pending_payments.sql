-- Verifica pagamentos pendentes
SELECT 
  p.id,
  p.external_id,
  p.status,
  p.payer_email,
  p.amount,
  p.created_at,
  o.id as order_id,
  o.status as order_status,
  lc.instagram_handle
FROM payments p
LEFT JOIN orders o ON o.id = p.order_id
LEFT JOIN live_carts lc ON lc.id = o.live_cart_id
WHERE p.created_at > NOW() - INTERVAL '2 hours'
ORDER BY p.created_at DESC
LIMIT 10;
