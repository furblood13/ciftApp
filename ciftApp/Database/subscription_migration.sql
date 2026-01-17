-- =====================================================
-- Premium Subscription Migration
-- Run this in Supabase SQL Editor
-- =====================================================

-- Add subscription columns to couples table
ALTER TABLE couples ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;
ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_type VARCHAR(20); -- 'trial', 'monthly', 'yearly'
ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_start_date TIMESTAMPTZ;
ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMPTZ;
ALTER TABLE couples ADD COLUMN IF NOT EXISTS original_transaction_id TEXT;

-- Verify columns added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'couples'
ORDER BY ordinal_position;
