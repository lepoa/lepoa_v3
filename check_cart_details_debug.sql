-- Dump all columns for the specific cart
SELECT * FROM live_carts WHERE id = '09da36f5-8f77-460c-b280-0c5e1e6a5427';

-- Check if live_carts is a TABLE or VIEW
SELECT relname, relkind 
FROM pg_class 
WHERE relname = 'live_carts';
