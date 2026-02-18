
-- Find Ana's customer record
WITH ana_customer AS (
    SELECT * FROM live_customers WHERE instagram_handle LIKE '%anamoukarzel%'
)
SELECT 
    c.id as customer_id, 
    c.instagram_handle, 
    c.nome,
    lc.id as cart_id,
    lc.status as cart_status,
    lc.created_at as cart_created_at,
    lc.live_event_id,
    lci.id as item_id,
    lci.product_id,
    lci.status as item_status,
    lci.separation_status,
    lci.created_at as item_created_at,
    pc.name as product_name
FROM ana_customer c
LEFT JOIN live_carts lc ON lc.customer_id = c.id
LEFT JOIN live_cart_items lci ON lci.live_cart_id = lc.id
LEFT JOIN product_catalog pc ON lci.product_id = pc.id
ORDER BY lc.created_at DESC;
