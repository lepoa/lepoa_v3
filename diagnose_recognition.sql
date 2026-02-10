-- Check what data we have for @laistmelo

-- 1. Check instagram_identities table
SELECT 
  'instagram_identities' as source,
  instagram_handle_raw,
  phone,
  customer_id,
  last_order_id,
  last_paid_at
FROM instagram_identities
WHERE instagram_handle_normalized = 'laistmelo';

-- 2. Check live_customers table
SELECT 
  'live_customers' as source,
  instagram_handle,
  nome,
  whatsapp,
  client_id
FROM live_customers
WHERE lower(trim(replace(instagram_handle, '@', ''))) = 'laistmelo'
ORDER BY created_at DESC
LIMIT 5;

-- 3. Check if there are paid orders for this handle
SELECT 
  'paid_orders' as source,
  o.id as order_id,
  o.customer_name,
  o.customer_phone,
  o.paid_at,
  lc.live_customer_id,
  c.nome as live_customer_name,
  c.whatsapp as live_customer_phone
FROM orders o
JOIN live_carts lc ON o.live_cart_id = lc.id
JOIN live_customers c ON lc.live_customer_id = c.id
WHERE lower(trim(replace(c.instagram_handle, '@', ''))) = 'laistmelo'
  AND o.status = 'pago'
ORDER BY o.paid_at DESC
LIMIT 3;

-- 4. Check payments table for email
SELECT 
  'payments' as source,
  p.order_id,
  p.payer_email,
  p.payer_phone,
  o.customer_name
FROM payments p
JOIN orders o ON p.order_id = o.id
JOIN live_carts lc ON o.live_cart_id = lc.id
JOIN live_customers c ON lc.live_customer_id = c.id
WHERE lower(trim(replace(c.instagram_handle, '@', ''))) = 'laistmelo'
ORDER BY p.created_at DESC
LIMIT 3;
