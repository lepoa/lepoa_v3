-- PART 1: ADD ENUM VALUES
-- Run this script FIRST to add the new tier definitions to the system.

DO $$
BEGIN
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
