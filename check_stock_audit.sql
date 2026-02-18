-- AUDITORIA DE ESTOQUE PARA O PRODUTO "Teste Oficial" (M)
SELECT 
    p.id,
    p.name,
    p.stock_by_size->>'M' as estoque_fisico,
    p.committed_by_size->>'M' as reservado_catalogo,
    v.available as disponivel_na_view,
    v.reserved as reservado_nas_lives
FROM product_catalog p
LEFT JOIN product_available_stock v ON v.product_id = p.id AND v.size = 'M'
WHERE p.name ILIKE '%Teste Oficial%';

-- VERIFICAR PEDIDOS DO CATÁLOGO QUE DEVERIAM ESTAR RESERVANDO M
SELECT 
    o.id,
    o.status,
    o.source,
    oi.quantity,
    oi.size
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE oi.product_id = (SELECT id FROM product_catalog WHERE name ILIKE '%Teste Oficial%' LIMIT 1)
  AND oi.size = 'M';

-- VERIFICAR CARRINHOS DE LIVE QUE DEVERIAM ESTAR RESERVANDO M
SELECT 
    lc.id,
    lc.status,
    lci.qtd,
    lci.variante->>'tamanho' as size
FROM live_carts lc
JOIN live_cart_items lci ON lci.live_cart_id = lc.id
WHERE lci.product_id = (SELECT id FROM product_catalog WHERE name ILIKE '%Teste Oficial%' LIMIT 1)
  AND lci.variante->>'tamanho' = 'M'
  AND lc.status NOT IN ('cancelado', 'expirado');
