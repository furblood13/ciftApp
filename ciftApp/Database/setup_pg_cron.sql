-- =====================================================
-- pg_cron Job Setup for Time Capsule Notifications
-- Run this in Supabase SQL Editor
-- =====================================================

-- First, enable the required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Remove existing job if it exists
SELECT cron.unschedule('check-capsules-hourly') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'check-capsules-hourly'
);

-- Schedule the job to run every 15 minutes
SELECT cron.schedule(
    'check-capsules-15min',
    '*/15 * * * *',  -- Every 15 minutes (at :00, :15, :30, :45)
    $$
    SELECT net.http_post(
        url := 'https://vyeqwtshfnmublhmvlhd.supabase.co/functions/v1/check-capsules',
        headers := jsonb_build_object(
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ5ZXF3dHNoZm5tdWJsaG12bGhkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYzMTYxMTYsImV4cCI6MjA4MTg5MjExNn0.N4qPatGEfEY7fYRd-iNXVZb3YrlEI_rgOVq4-FbcBgk',
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);

-- Verify the job is scheduled
SELECT * FROM cron.job WHERE jobname = 'check-capsules-15min';

-- To see job run history:
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
