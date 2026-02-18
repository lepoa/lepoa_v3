-- PART 2: UPDATE DATA
-- Run this script SECOND, AFTER running fix_legacy_rewards_enum.sql
-- This updates the existing rewards to use the new tier names.

UPDATE loyalty_rewards
SET min_tier = 'poa_gold'::loyalty_tier
WHERE min_tier::text = 'classica';

UPDATE loyalty_rewards
SET min_tier = 'poa_platinum'::loyalty_tier
WHERE min_tier::text = 'icone';

-- Verify the update
SELECT name, min_tier FROM loyalty_rewards;
