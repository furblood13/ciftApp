-- Fix Storage RLS for timeline-photos bucket
-- Run this in Supabase SQL Editor

-- First, drop existing policies if they exist
DROP POLICY IF EXISTS "Couple members can upload photos" ON storage.objects;
DROP POLICY IF EXISTS "Couple members can view their photos" ON storage.objects;
DROP POLICY IF EXISTS "Couple members can delete their photos" ON storage.objects;

-- Create simpler policies that work
-- Allow authenticated users to upload to timeline-photos bucket
CREATE POLICY "Allow authenticated uploads to timeline-photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'timeline-photos');

-- Allow public read access (since bucket is public)
CREATE POLICY "Allow public read for timeline-photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'timeline-photos');

-- Allow authenticated users to delete their photos
CREATE POLICY "Allow authenticated delete for timeline-photos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'timeline-photos');

-- Verify bucket exists and is public
SELECT id, name, public FROM storage.buckets WHERE id = 'timeline-photos';
