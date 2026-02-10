
print("Diagnosing 'operator does not exist: text[] -> integer' error...");
print("This error means a TEXT ARRAY column is being accessed like a JSON ARRAY (using -> operator with an integer index).");
print("Please run this SQL in your Supabase Dashboard -> SQL Editor to identify the problematic trigger or column:");

print(`
-- 1. Check columns of live_carts and live_cart_items to find TEXT[] columns
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name IN ('live_carts', 'live_cart_items')
  AND data_type = 'ARRAY' 
  AND udt_name = '_text';

-- 2. List all triggers on live_carts and live_cart_items
SELECT 
    event_object_table as table_name,
    trigger_name,
    action_statement
FROM information_schema.triggers
WHERE event_object_table IN ('live_carts', 'live_cart_items');
`);
