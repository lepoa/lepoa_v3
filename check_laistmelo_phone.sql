
-- Verificar dados do cliente laistmelo
SELECT 
    lc.id as cart_id,
    lc.status as cart_status,
    cust.id as customer_id,
    cust.instagram_handle,
    cust.whatsapp,
    cust.nome
FROM public.live_customers cust
JOIN public.live_carts lc ON lc.live_customer_id = cust.id
WHERE cust.instagram_handle ILIKE '%laistmelo%';
