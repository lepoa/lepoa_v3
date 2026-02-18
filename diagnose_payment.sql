-- Diagnose the last live cart payment attempt
WITH last_cart AS (
  SELECT id, status, created_at, total, mp_preference_id
  FROM live_carts
  ORDER BY created_at DESC
  LIMIT 1
)
SELECT 
  lc.id as cart_id,
  lc.status as cart_status,
  lc.total,
  lc.mp_preference_id,
  -- Check if we received any webhook event for this cart
  (
    SELECT count(*) 
    FROM mp_payment_events 
    WHERE live_cart_id = lc.id 
       OR (payload->>'data'::text)::jsonb->>'id' = lc.mp_preference_id
  ) as webhook_events_count,
  -- Get details of the last webhook event if any
  (
    SELECT jsonb_build_object(
      'event_type', event_type,
      'mp_status', mp_status,
      'received_at', received_at,
      'error_message', error_message
    )
    FROM mp_payment_events 
    WHERE live_cart_id = lc.id 
    ORDER BY received_at DESC 
    LIMIT 1
  ) as last_webhook_event
FROM last_cart lc;
