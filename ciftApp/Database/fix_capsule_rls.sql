-- Add UPDATE and DELETE policies for time_capsules
-- Run this in Supabase SQL Editor

-- Allow couple members to update their capsules (for unlocking by recipient)
CREATE POLICY "Couple members can update capsules"
    ON time_capsules FOR UPDATE
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

-- Allow couple members to delete their capsules  
CREATE POLICY "Couple members can delete capsules"
    ON time_capsules FOR DELETE
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

-- Verify policies
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'time_capsules';
