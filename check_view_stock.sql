-- Verifica se a view product_available_stock tem dados para o produto "teste sem foto"
SELECT *
FROM product_available_stock
WHERE product_id = (
  SELECT id FROM product_catalog WHERE name = 'teste sem foto'
);
