-- =====================================================
-- Timeline Events Schema Update
-- Run this in Supabase SQL Editor
-- =====================================================

-- 1. Add new enums for milestone types
DO $$ BEGIN
    CREATE TYPE milestone_type AS ENUM (
        'first_kiss', 'first_date', 'first_trip', 
        'engagement', 'wedding', 'anniversary',
        'moved_in', 'first_fight', 'custom'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- 2. Update timeline_events table with new columns
ALTER TABLE timeline_events 
    ADD COLUMN IF NOT EXISTS photo_url TEXT,
    ADD COLUMN IF NOT EXISTS location_name VARCHAR(255),
    ADD COLUMN IF NOT EXISTS location_latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS location_longitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS who_started UUID REFERENCES profiles(id),
    ADD COLUMN IF NOT EXISTS lesson_learned TEXT,
    ADD COLUMN IF NOT EXISTS linked_conflict_id UUID REFERENCES timeline_events(id),
    ADD COLUMN IF NOT EXISTS is_milestone BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS milestone_type milestone_type,
    ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES profiles(id);

-- 3. Create storage bucket for timeline photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('timeline-photos', 'timeline-photos', true)
ON CONFLICT (id) DO NOTHING;

-- 4. Storage RLS policies
CREATE POLICY "Couple members can upload photos"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'timeline-photos' AND
    (storage.foldername(name))[1] IN (
        SELECT couple_id::text FROM profiles WHERE id = auth.uid()
    )
);

CREATE POLICY "Couple members can view their photos"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'timeline-photos' AND
    (storage.foldername(name))[1] IN (
        SELECT couple_id::text FROM profiles WHERE id = auth.uid()
    )
);

CREATE POLICY "Couple members can delete their photos"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'timeline-photos' AND
    (storage.foldername(name))[1] IN (
        SELECT couple_id::text FROM profiles WHERE id = auth.uid()
    )
);

-- 5. Add more conflict categories
DO $$ BEGIN
    ALTER TYPE conflict_category ADD VALUE IF NOT EXISTS 'Communication';
    ALTER TYPE conflict_category ADD VALUE IF NOT EXISTS 'Time';
    ALTER TYPE conflict_category ADD VALUE IF NOT EXISTS 'Family';
    ALTER TYPE conflict_category ADD VALUE IF NOT EXISTS 'Trust';
    ALTER TYPE conflict_category ADD VALUE IF NOT EXISTS 'Other';
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- 6. Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_timeline_events_created_by ON timeline_events(created_by);
CREATE INDEX IF NOT EXISTS idx_timeline_events_type ON timeline_events(type);
CREATE INDEX IF NOT EXISTS idx_timeline_events_date_desc ON timeline_events(date DESC);

-- 7. Verify changes
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'timeline_events'
ORDER BY ordinal_position;
