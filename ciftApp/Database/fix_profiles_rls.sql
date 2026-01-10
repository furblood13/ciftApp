-- =====================================================
-- SIMPLE FIX FOR PROFILES RLS
-- This allows all authenticated users to read all profiles
-- (Safe for a couples app where only partners interact)
-- Run this in Supabase SQL Editor
-- =====================================================

-- Drop ALL existing SELECT policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view their profile" ON profiles;
DROP POLICY IF EXISTS "Users can view own and partner profiles" ON profiles;
DROP POLICY IF EXISTS "Enable read access for users" ON profiles;

-- Simple policy: Authenticated users can read all profiles
CREATE POLICY "Authenticated users can view profiles"
    ON profiles FOR SELECT
    TO authenticated
    USING (true);

-- Update policy remains for own profile only
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());
