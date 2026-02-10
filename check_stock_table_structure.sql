-- Verifica a estrutura da tabela public_product_stock
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'public_product_stock'
ORDER BY ordinal_position;
