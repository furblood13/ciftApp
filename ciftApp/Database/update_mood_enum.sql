-- =====================================================
-- Update mood_type enum to support new moods
-- IMPORTANT: Run each ALTER TYPE statement SEPARATELY!
-- (Click "Run" after each one before running the next)
-- =====================================================

-- Step 1: Run this ALONE first
ALTER TYPE mood_type ADD VALUE IF NOT EXISTS 'Loved';

-- Step 2: Run this ALONE second  
ALTER TYPE mood_type ADD VALUE IF NOT EXISTS 'NeedAttention';

-- Step 3: Run this ALONE third
ALTER TYPE mood_type ADD VALUE IF NOT EXISTS 'Sad';

-- Step 4: Verify (run after all above are done)
SELECT enum_range(NULL::mood_type);
