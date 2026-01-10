-- =====================================================
-- Time Capsule Privacy Features - Database Migration
-- Run this in Supabase SQL Editor
-- =====================================================

-- Add visibility columns to time_capsules
DO $$ 
BEGIN
    -- Hide title from recipient before unlock
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'time_capsules' AND column_name = 'hide_title'
    ) THEN
        ALTER TABLE time_capsules ADD COLUMN hide_title BOOLEAN DEFAULT FALSE;
    END IF;

    -- Hide countdown from recipient
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'time_capsules' AND column_name = 'hide_countdown'
    ) THEN
        ALTER TABLE time_capsules ADD COLUMN hide_countdown BOOLEAN DEFAULT FALSE;
    END IF;

    -- Hide message preview (completely secret until unlock)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'time_capsules' AND column_name = 'hide_preview'
    ) THEN
        ALTER TABLE time_capsules ADD COLUMN hide_preview BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- Allow users to delete their own capsules
CREATE POLICY "Users can delete own capsules"
    ON time_capsules FOR DELETE
    USING (
        created_by = auth.uid() 
        OR recipient_id = auth.uid()
    );
