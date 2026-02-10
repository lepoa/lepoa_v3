-- Verifica se product_available_stock é uma view ou tabela
SELECT 
  table_name,
  table_type
FROM information_schema.tables
WHERE table_schema = 'public' 
  AND table_name IN ('product_available_stock', 'public_product_stock')
ORDER BY table_name;

-- Mostra a definição da view
SELECT pg_get_viewdef('product_available_stock', true);
