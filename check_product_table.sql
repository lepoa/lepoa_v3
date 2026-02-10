-- Verifica a estrutura da tabela product_catalog
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'product_catalog'
  AND table_schema = 'public'
ORDER BY ordinal_position;
