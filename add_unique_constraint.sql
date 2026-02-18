-- Add unique constraint to customers user_id to allow upsert
-- This is necessary for the Quiz retry logic to work correctly

DO $$
BEGIN
    -- Check if constraint already exists to avoid errors
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'customers_user_id_key' 
        AND conrelid = 'public.customers'::regclass
    ) THEN
        -- Add unique constraint
        ALTER TABLE public.customers
        ADD CONSTRAINT customers_user_id_key UNIQUE (user_id);
    END IF;
END $$;
