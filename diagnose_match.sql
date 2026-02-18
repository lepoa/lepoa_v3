-- Verificando por que o vínculo falhou
WITH last_cart AS (
  SELECT id, live_customer_id, status, user_id
  FROM live_carts 
  WHERE status = 'pago' 
  ORDER BY created_at DESC 
  LIMIT 1
)
SELECT 
  lc.id as cart_id,
  lc.status,
  lc.user_id as cart_user_id,
  cust.nome as nome_no_pedido,
  cust.whatsapp as telefone_no_pedido,
  p.id as id_do_perfil_encontrado,
  p.name as nome_do_perfil,
  p.whatsapp as telefone_do_perfil
FROM last_cart lc
JOIN live_customers cust ON lc.live_customer_id = cust.id
LEFT JOIN profiles p ON regexp_replace(p.whatsapp, '\D', '', 'g') = regexp_replace(cust.whatsapp, '\D', '', 'g');
