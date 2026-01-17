-- Premium Profile Migration
-- This adds premium columns to profiles table (Source of Truth)
-- The couples table still has is_premium but acts as a cache

-- Step 1: Add premium columns to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_type TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS original_transaction_id TEXT;

-- Step 2: Migrate existing premium users from couples to profiles
-- This copies premium status from couples to both partner profiles
UPDATE profiles p
SET 
    is_premium = c.is_premium,
    subscription_end_date = c.subscription_end_date,
    subscription_type = c.subscription_type
FROM couples c
WHERE p.couple_id = c.id
  AND c.is_premium = true;

-- Step 3: Create a trigger function to sync couples premium when profiles change
CREATE OR REPLACE FUNCTION sync_couple_premium()
RETURNS TRIGGER AS $$
BEGIN
    -- When a profile's is_premium or couple_id changes, update the couple
    IF NEW.couple_id IS NOT NULL THEN
        UPDATE couples
        SET is_premium = (
            SELECT COALESCE(bool_or(is_premium), false)
            FROM profiles
            WHERE couple_id = NEW.couple_id
        )
        WHERE id = NEW.couple_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Create trigger on profiles table (fires on is_premium OR couple_id change)
DROP TRIGGER IF EXISTS trigger_sync_couple_premium ON profiles;
CREATE TRIGGER trigger_sync_couple_premium
    AFTER UPDATE OF is_premium, couple_id ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION sync_couple_premium();

-- Also trigger on INSERT (for new users joining a couple)
DROP TRIGGER IF EXISTS trigger_sync_couple_premium_insert ON profiles;
CREATE TRIGGER trigger_sync_couple_premium_insert
    AFTER INSERT ON profiles
    FOR EACH ROW
    WHEN (NEW.couple_id IS NOT NULL)
    EXECUTE FUNCTION sync_couple_premium();

-- Step 5: Enable realtime for couples table (if not already)
-- Run this only once, ignore if already exists
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE couples;
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

