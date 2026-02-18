-- Tenta vincular pedidos orfãos aos usuários baseando-se no WhatsApp ou Telefone
UPDATE live_carts lc
SET user_id = p.id
FROM profiles p
WHERE lc.user_id IS NULL
  AND lc.status IN ('pago', 'enviado', 'entregue')
  AND p.whatsapp IS NOT NULL
  AND length(p.whatsapp) > 8
  AND (
    -- Remove tudo que não é número para comparar
    regexp_replace(p.whatsapp, '\D', '', 'g') 
    = 
    regexp_replace(
      (SELECT whatsapp FROM live_customers WHERE id = lc.live_customer_id LIMIT 1), 
      '\D', '', 'g'
    )
  ); 
