-- Adiciona coluna de email na tabela instagram_identities
ALTER TABLE public.instagram_identities 
ADD COLUMN IF NOT EXISTS email TEXT;

-- Cria índice para busca rápida por email
CREATE INDEX IF NOT EXISTS idx_instagram_identities_email 
ON public.instagram_identities(email);

-- Popula o email do @laistmelo baseado no último pagamento
UPDATE public.instagram_identities
SET email = (
  SELECT payer_email 
  FROM payments 
  WHERE order_id = instagram_identities.last_order_id 
  LIMIT 1
)
WHERE instagram_handle_normalized = 'laistmelo'
  AND last_order_id IS NOT NULL;

-- Verifica se funcionou
SELECT 
  instagram_handle_raw,
  phone,
  email,
  last_order_id
FROM instagram_identities
WHERE instagram_handle_normalized = 'laistmelo';
