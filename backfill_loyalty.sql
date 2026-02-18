-- Backfill customer_loyalty from profiles for users who have points but missing/lower loyalty
-- This ensures the "Legacy" points from the quiz are reflected in the Club

DO $$
DECLARE
  r RECORD;
  v_tier text;
BEGIN
  FOR r IN SELECT * FROM profiles WHERE quiz_points > 0 LOOP
    
    -- Calculate proper tier based on points
    IF r.quiz_points >= 6000 THEN
      v_tier := 'poa_black';
    ELSIF r.quiz_points >= 3000 THEN
      v_tier := 'poa_platinum';
    ELSIF r.quiz_points >= 1000 THEN
      v_tier := 'poa_gold';
    ELSE
      v_tier := 'poa';
    END IF;

    -- Upsert into customer_loyalty
    INSERT INTO customer_loyalty (user_id, current_points, lifetime_points, annual_points, current_tier, created_at, updated_at)
    VALUES (
      r.user_id, 
      r.quiz_points, 
      r.quiz_points, 
      r.quiz_points, 
      v_tier::loyalty_tier,
      now(),
      now()
    )
    ON CONFLICT (user_id) DO UPDATE
    SET 
      current_points = GREATEST(customer_loyalty.current_points, EXCLUDED.current_points),
      lifetime_points = GREATEST(customer_loyalty.lifetime_points, EXCLUDED.lifetime_points),
      annual_points = GREATEST(customer_loyalty.annual_points, EXCLUDED.annual_points),
      current_tier = CASE 
        WHEN EXCLUDED.annual_points > customer_loyalty.annual_points THEN EXCLUDED.current_tier 
        ELSE customer_loyalty.current_tier 
      END,
      updated_at = now();
      
  END LOOP;
END $$;
