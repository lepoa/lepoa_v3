-- Raio-X do Estoque do produto "2 reais"
SELECT 
    p.name as Produto,
    lci.status as Status_Item,
    lci.created_at,
    lc.instagram_handle as Cliente,
    lc_cart.status as Status_Carrinho
FROM live_cart_items lci
JOIN product_catalog p ON lci.product_id = p.id
LEFT JOIN live_carts lc_cart ON lci.live_cart_id = lc_cart.id
LEFT JOIN live_customers lc ON lc_cart.live_customer_id = lc.id
WHERE p.name ILIKE '%2 reais%' 
  AND lci.status IN ('reservado', 'confirmado')
ORDER BY lci.created_at DESC;
