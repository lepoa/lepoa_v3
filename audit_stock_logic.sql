-- Extrair a definição exata da View de Estoque para auditar a lógica
SELECT pg_get_viewdef('product_available_stock', true) as definicao_view;

-- Verificar a função que bloqueia o estoque ao adicionar no carrinho
SELECT prosrc FROM pg_proc WHERE proname = 'live_add_to_cart' OR proname = 'quick_launch';
