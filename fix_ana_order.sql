-- 1. Preenche os dados do cliente (Usei seu celular do print anterior)
UPDATE live_customers
SET 
  nome = 'Ana Carolina', 
  whatsapp = '5562982691262'  -- Assumindo formato 55+DDD+NÚMERO
WHERE id = (
  SELECT live_customer_id 
  FROM live_carts 
  WHERE id = '09da36f5-8f77-460c-b280-0c5e1e6a5427'
);

-- 2. Vincula o pedido ao usuário que tem esse celular
UPDATE live_carts lc
SET user_id = p.id
FROM profiles p
JOIN auth.users u ON u.id = p.id
WHERE lc.id = '09da36f5-8f77-460c-b280-0c5e1e6a5427'
  AND regexp_replace(p.whatsapp, '\D', '', 'g') LIKE '%982691262%';
