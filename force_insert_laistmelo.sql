-- FORCE INSERT para @laistmelo especificamente
-- Baseado nos dados que encontramos

-- Primeiro, vamos garantir que temos o email (se existir)
DO $$
DECLARE
  v_order_id UUID := '86cc0d7c-e989-4b7e-bcd7-f3285ec20666';
  v_email TEXT;
BEGIN
  -- Tenta pegar email do pagamento
  SELECT payer_email INTO v_email
  FROM payments
  WHERE order_id = v_order_id
  LIMIT 1;

  -- Insere ou atualiza a identidade
  INSERT INTO instagram_identities (
    instagram_handle_normalized,
    instagram_handle_raw,
    phone,
    last_order_id,
    last_paid_at
  ) VALUES (
    'laistmelo',
    '@laistmelo',
    '5562982691262',
    v_order_id,
    '2026-02-09 16:36:11+00'::timestamptz
  )
  ON CONFLICT (instagram_handle_normalized) 
  DO UPDATE SET
    phone = EXCLUDED.phone,
    last_order_id = EXCLUDED.last_order_id,
    last_paid_at = EXCLUDED.last_paid_at,
    updated_at = now();

  RAISE NOTICE 'Identity created/updated for @laistmelo';
END $$;

-- Verifica se funcionou
SELECT 
  instagram_handle_raw,
  phone,
  last_order_id,
  last_paid_at
FROM instagram_identities
WHERE instagram_handle_normalized = 'laistmelo';
