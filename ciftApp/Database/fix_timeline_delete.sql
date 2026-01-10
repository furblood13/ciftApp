-- Fix: Add DELETE policy for timeline_events
-- The table has SELECT, INSERT, UPDATE policies but was missing DELETE

-- Drop if exists (in case of re-run)
DROP POLICY IF EXISTS "timeline_events_delete_policy" ON timeline_events;

-- Create DELETE policy: Users can delete events from their own couple
CREATE POLICY "timeline_events_delete_policy"
    ON timeline_events FOR DELETE
    USING (
        couple_id IN (
            SELECT couple_id FROM profiles WHERE id = auth.uid()
        )
    );

-- Verify the policy was created
-- You can check with: SELECT * FROM pg_policies WHERE tablename = 'timeline_events';
