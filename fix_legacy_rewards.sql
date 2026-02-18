-- Fix loyalty_tier enum and update legacy rewards
-- This script adds new tier values to the enum and then updates the rewards table
-- Run this in Supabase SQL Editor

DO $$
BEGIN
    -- 1. Add new enum values if they don't exist
    -- We use ALTER TYPE ... ADD VALUE IF NOT EXISTS which is supported in recent Postgres versions
    -- If your Postgres version is older, it might need a different approach, but Supabase usually supports this.
    
    -- Add 'poa_gold'
    BEGIN
        ALTER TYPE loyalty_tier ADD VALUE 'poa_gold';
    EXCEPTION
        WHEN duplicate_object THEN NULL; -- Value already exists
    END;

    -- Add 'poa_platinum'
    BEGIN
        ALTER TYPE loyalty_tier ADD VALUE 'poa_platinum';
    EXCEPTION
        WHEN duplicate_object THEN NULL;
    END;

    -- Add 'poa_black'
    BEGIN
        ALTER TYPE loyalty_tier ADD VALUE 'poa_black';
    EXCEPTION
        WHEN duplicate_object THEN NULL;
    END;
    
END $$;

-- 2. Update legacy tier names in loyalty_rewards table
UPDATE loyalty_rewards
SET min_tier = 'poa_gold'::loyalty_tier
WHERE min_tier::text = 'classica';

UPDATE loyalty_rewards
SET min_tier = 'poa_platinum'::loyalty_tier
WHERE min_tier::text = 'icone';

-- 3. Verify the update
SELECT name, min_tier FROM loyalty_rewards;
