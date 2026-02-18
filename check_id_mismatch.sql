-- Diagnóstico Final de Identidade
SELECT 
  id as cart_id, 
  user_id as user_no_cart, 
  status,
  updated_at
FROM live_carts 
WHERE id = '09da36f5-8f77-460c-b280-0c5e1e6a5427';
