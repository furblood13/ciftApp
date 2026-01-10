-- =====================================================
-- Add creator_id to couples table
-- Run this in Supabase SQL Editor
-- =====================================================

-- Add creator_id column to track who created the invite code
ALTER TABLE couples ADD COLUMN IF NOT EXISTS creator_id UUID REFERENCES auth.users(id);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_couples_creator_id ON couples(creator_id);
