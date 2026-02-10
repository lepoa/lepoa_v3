-- Verificar Cron Jobs agendados
SELECT * FROM cron.job;

-- Verificar se a extensão pg_net está ativa (necessária para chamar edge functions)
SELECT * FROM pg_available_extensions WHERE name = 'pg_net';

-- Contar quantas reservas fantasmas existem (mais de 2 hora, status reservado)
SELECT count(*) as reservas_fantasmas
FROM live_cart_items
WHERE status = 'reservado'
  AND (expiracao_reserva_em < NOW() OR expiracao_reserva_em IS NULL)
  AND created_at < NOW() - INTERVAL '2 hours';
