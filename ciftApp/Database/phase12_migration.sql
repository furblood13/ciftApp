-- Add photo_urls array column to timeline_events
ALTER TABLE timeline_events 
ADD COLUMN IF NOT EXISTS photo_urls TEXT[];

-- Ensure who_started column exists (it should, but just in case)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='timeline_events' AND column_name='who_started') THEN
        ALTER TABLE timeline_events ADD COLUMN who_started UUID REFERENCES auth.users(id);
    END IF;
END $$;
