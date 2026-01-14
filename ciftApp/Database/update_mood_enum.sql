-- =====================================================
-- Add Angry to mood_type enum
-- Run this in Supabase SQL Editor
-- =====================================================

-- Add 'Angry' to mood_type enum
ALTER TYPE mood_type ADD VALUE IF NOT EXISTS 'Angry';

-- Verify the enum values
SELECT enum_range(NULL::mood_type);
