-- 1. Destrava o último carrinho aberto
UPDATE live_carts
SET status = 'pago', paid_at = now()
WHERE id = (
  SELECT id FROM live_carts 
  WHERE status = 'aberto' 
  ORDER BY created_at DESC 
  LIMIT 1
);

-- 2. Vincula ao usuário CORRETO (apenas status 'pago')
UPDATE live_carts lc
SET user_id = p.id
FROM profiles p
JOIN auth.users u ON u.id = p.id
WHERE lc.user_id IS NULL
  AND lc.status = 'pago' -- CORREÇÃO: Apenas 'pago' é válido aqui
  AND p.whatsapp IS NOT NULL
  AND length(p.whatsapp) > 8
  AND regexp_replace(p.whatsapp, '\D', '', 'g') = regexp_replace((SELECT whatsapp FROM live_customers WHERE id = lc.live_customer_id LIMIT 1), '\D', '', 'g');
