
-- Adicionar coluna instagram na tabela customers
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS instagram text;

-- Sincronizar handles de instagram da live para o CRM principal
UPDATE public.customers c
SET instagram = lc.instagram_handle
FROM public.live_customers lc
WHERE lc.client_id = c.id AND c.instagram IS NULL;
