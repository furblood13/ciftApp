-- =====================================================
-- CLEAN UP AND FIX RLS POLICIES
-- Run this FIRST in Supabase SQL Editor
-- =====================================================

-- 1. Delete all test data
DELETE FROM couples;

-- 2. Reset all profile partner/couple links
UPDATE profiles SET partner_id = NULL, couple_id = NULL;

-- 3. Fix couples RLS policies
DROP POLICY IF EXISTS "Anyone can create a couple" ON couples;
DROP POLICY IF EXISTS "Anyone can view couples" ON couples;
DROP POLICY IF EXISTS "Couple members can update their couple" ON couples;
DROP POLICY IF EXISTS "Couple members can view their couple" ON couples;
DROP POLICY IF EXISTS "Anyone can create a couple (for invite code generation)" ON couples;

-- Allow authenticated users to create couples
CREATE POLICY "Authenticated users can create couples"
    ON couples FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Allow viewing couples only if you created it OR you're a member
CREATE POLICY "Users can view relevant couples"
    ON couples FOR SELECT
    TO authenticated
    USING (
        creator_id = auth.uid() OR 
        id IN (SELECT couple_id FROM profiles WHERE id = auth.uid())
    );

-- Allow updating couples you're part of
CREATE POLICY "Users can update their couples"
    ON couples FOR UPDATE
    TO authenticated
    USING (
        creator_id = auth.uid() OR 
        id IN (SELECT couple_id FROM profiles WHERE id = auth.uid())
    );

-- Allow deleting couples you created (for cancel)
CREATE POLICY "Creators can delete their couples"
    ON couples FOR DELETE
    TO authenticated
    USING (creator_id = auth.uid());

-- 4. Special policy for finding couples by invite code (needed for joining)
-- We need a way to find a couple by invite_code even if not creator
-- Solution: Allow SELECT when querying by invite_code
DROP POLICY IF EXISTS "Users can view relevant couples" ON couples;

CREATE POLICY "Users can view couples"
    ON couples FOR SELECT
    TO authenticated
    USING (true);
