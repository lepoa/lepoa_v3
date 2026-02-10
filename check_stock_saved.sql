-- Verifica o produto "2 reais" que você cadastrou
SELECT 
  name,
  sku,
  sizes,
  stock_by_size,
  created_at
FROM product_catalog
WHERE name ILIKE '%2 reais%' OR name ILIKE '%swqs%'
ORDER BY created_at DESC
LIMIT 3;
