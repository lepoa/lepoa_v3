-- Adiciona o email à identidade do @laistmelo

DO $$
DECLARE
  v_email TEXT;
BEGIN
  -- Busca o email do pagamento do último pedido
  SELECT payer_email INTO v_email
  FROM payments
  WHERE order_id = '86cc0d7c-e989-4b7e-bcd7-f3285ec20666'
  LIMIT 1;

  -- Se encontrou email, atualiza a tabela
  -- (Mas a tabela instagram_identities não tem coluna email! Precisamos adicionar)
  
  RAISE NOTICE 'Email found: %', COALESCE(v_email, 'NULL');
END $$;

-- Vamos verificar se a tabela tem coluna de email
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'instagram_identities' 
  AND table_schema = 'public'
ORDER BY ordinal_position;
