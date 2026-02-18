-- Check for paid live carts without user_id in the last 24 hours
SELECT 
  lc.id, 
  lc.status, 
  lc.created_at, 
  lc.paid_at, 
  lc.user_id,
  lc.live_customer_id,
  c.nome,
  c.whatsapp
FROM live_carts lc
LEFT JOIN live_customers c ON lc.live_customer_id = c.id
WHERE 
  lc.status IN ('pago', 'enviado', 'entregue') 
  AND lc.paid_at > now() - interval '24 hours'
ORDER BY lc.paid_at DESC;

-- Get count of paid carts with vs without user_id
SELECT 
  COUNT(*) FILTER (WHERE user_id IS NOT NULL) as linked_to_user,
  COUNT(*) FILTER (WHERE user_id IS NULL) as not_linked,
  COUNT(*) as total_paid_last_24h
FROM live_carts
WHERE 
  status IN ('pago', 'enviado', 'entregue') 
  AND paid_at > now() - interval '24 hours';
