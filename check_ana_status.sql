
-- 1. Buscar cliente
SELECT id, instagram_handle, nome, user_id 
FROM live_customers 
WHERE instagram_handle ILIKE '%anamou%' OR instagram_handle ILIKE '%moukarzel%';

-- 2. Buscar carrinhos desse cliente
SELECT id, status, live_event_id, created_at, operational_status, total
FROM live_carts 
WHERE live_customer_id IN (
    SELECT id FROM live_customers 
    WHERE instagram_handle ILIKE '%anamou%' OR instagram_handle ILIKE '%moukarzel%'
);

-- 3. Buscar itens dos carrinhos
SELECT id, product_id, status, qtd, separation_status, live_cart_id
FROM live_cart_items 
WHERE live_cart_id IN (
    SELECT id FROM live_carts 
    WHERE live_customer_id IN (
        SELECT id FROM live_customers 
        WHERE instagram_handle ILIKE '%anamou%' OR instagram_handle ILIKE '%moukarzel%'
    )
);
