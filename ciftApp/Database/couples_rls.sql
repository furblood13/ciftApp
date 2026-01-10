-- =====================================================
-- Couples Table RLS Policies
-- Run this in Supabase SQL Editor
-- =====================================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "Couple members can view their couple" ON couples;
DROP POLICY IF EXISTS "Anyone can create a couple (for invite code generation)" ON couples;
DROP POLICY IF EXISTS "Couple members can update their couple" ON couples;
DROP POLICY IF EXISTS "Anyone can view couples by invite code" ON couples;

-- Allow anyone to create a couple (needed for invite code generation)
CREATE POLICY "Anyone can create a couple"
    ON couples FOR INSERT
    WITH CHECK (true);

-- Allow anyone to read couples (needed to find by invite code)
CREATE POLICY "Anyone can view couples"
    ON couples FOR SELECT
    USING (true);

-- Allow couple members to update their couple
CREATE POLICY "Couple members can update their couple"
    ON couples FOR UPDATE
    USING (true);
