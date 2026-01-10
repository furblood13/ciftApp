-- =====================================================
-- Time Capsule Feature - Database Migration
-- Run this in Supabase SQL Editor
-- =====================================================

-- Add new columns to time_capsules (if not exists)
DO $$ 
BEGIN
    -- Add created_by column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'time_capsules' AND column_name = 'created_by'
    ) THEN
        ALTER TABLE time_capsules ADD COLUMN created_by UUID REFERENCES profiles(id);
    END IF;

    -- Add recipient_id column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'time_capsules' AND column_name = 'recipient_id'
    ) THEN
        ALTER TABLE time_capsules ADD COLUMN recipient_id UUID REFERENCES profiles(id);
    END IF;

    -- Add notification_sent column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'time_capsules' AND column_name = 'notification_sent'
    ) THEN
        ALTER TABLE time_capsules ADD COLUMN notification_sent BOOLEAN DEFAULT FALSE;
    END IF;

    -- Add title column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'time_capsules' AND column_name = 'title'
    ) THEN
        ALTER TABLE time_capsules ADD COLUMN title VARCHAR(100);
    END IF;
END $$;

-- Add apns_token to profiles (if not exists)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'apns_token'
    ) THEN
        ALTER TABLE profiles ADD COLUMN apns_token TEXT;
    END IF;
END $$;

-- Create index for faster capsule queries
CREATE INDEX IF NOT EXISTS idx_time_capsules_unlock_notification 
ON time_capsules(unlock_date, notification_sent, is_locked);

-- =====================================================
-- pg_cron Job Setup (Run in SQL Editor)
-- This calls the Edge Function every hour
-- =====================================================

-- Enable pg_cron extension (if not already)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the job to run every hour
SELECT cron.schedule(
    'check-capsules-hourly',
    '0 * * * *',  -- Every hour at :00
    $$
    SELECT net.http_post(
        url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/check-capsules',
        headers := jsonb_build_object(
            'Authorization', 'Bearer YOUR_ANON_KEY',
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);

-- To see scheduled jobs:
-- SELECT * FROM cron.job;

-- To remove a job:
-- SELECT cron.unschedule('check-capsules-hourly');
