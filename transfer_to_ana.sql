-- TRANSFERIR PEDIDO PARA ANA CAROLINA
-- O pedido estava na conta da Laís, vamos mover para a Ana (ID terminado em 62f5)

-- 1. Atualizar o Carrinho da Live
UPDATE live_carts
SET user_id = '08d57daf-1759-4c3c-a740-336f0eed62f5' -- ID da Ana Carolina (acmoukarzel@hotmail.com)
WHERE id = '09da36f5-8f77-460c-b280-0c5e1e6a5427';

-- 2. Atualizar o Pedido Gerado
UPDATE orders
SET user_id = '08d57daf-1759-4c3c-a740-336f0eed62f5' -- ID da Ana Carolina
WHERE id = 'abcbe4b1-6625-4486-a367-a72b5f1f4d06';
