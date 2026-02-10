-- Verifica os dados de estoque dos produtos recentes
SELECT 
  id,
  name,
  sku,
  sizes,
  stock_by_size,
  created_at
FROM product_catalog
ORDER BY created_at DESC
LIMIT 5;
