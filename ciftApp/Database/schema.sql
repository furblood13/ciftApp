-- =====================================================
-- Us & Time - Database Schema
-- Phase 1: Authentication & Profiles
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- ENUMS
-- =====================================================

-- Mood types for user status
CREATE TYPE mood_type AS ENUM ('Happy', 'Tired', 'LeaveMeAlone', 'InLove');

-- Event types for timeline (Phase 2)
CREATE TYPE event_type AS ENUM ('Memory', 'Conflict', 'Peace');

-- Conflict categories (Phase 2)
CREATE TYPE conflict_category AS ENUM ('Food', 'Jealousy', 'Finance', 'Chores');

-- =====================================================
-- TABLES
-- =====================================================

-- Couples table (must be created before profiles due to FK)
CREATE TABLE couples (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    start_date DATE DEFAULT CURRENT_DATE,
    invite_code VARCHAR(6) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User profiles (linked to Supabase Auth)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(50),
    avatar_url TEXT,
    partner_id UUID REFERENCES profiles(id),
    couple_id UUID REFERENCES couples(id),
    current_mood mood_type DEFAULT 'Happy',
    last_latitude DOUBLE PRECISION,
    last_longitude DOUBLE PRECISION,
    last_location_updated TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Timeline events (Phase 2 - created now for schema completeness)
CREATE TABLE timeline_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID REFERENCES couples(id) ON DELETE CASCADE,
    type event_type NOT NULL,
    date DATE DEFAULT CURRENT_DATE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    conflict_category conflict_category,
    severity INTEGER CHECK (severity >= 1 AND severity <= 10),
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Time capsules (Phase 2)
CREATE TABLE time_capsules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID REFERENCES couples(id) ON DELETE CASCADE,
    media_url TEXT,
    message_content TEXT,
    unlock_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_locked BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;
ALTER TABLE timeline_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE time_capsules ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can view partner profile"
    ON profiles FOR SELECT
    USING (id = (SELECT partner_id FROM profiles WHERE id = auth.uid()));

-- Couples policies
CREATE POLICY "Couple members can view their couple"
    ON couples FOR SELECT
    USING (id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Anyone can create a couple (for invite code generation)"
    ON couples FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Couple members can update their couple"
    ON couples FOR UPDATE
    USING (id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

-- Timeline events policies
CREATE POLICY "Couple members can view their events"
    ON timeline_events FOR SELECT
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Couple members can insert events"
    ON timeline_events FOR INSERT
    WITH CHECK (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Couple members can update events"
    ON timeline_events FOR UPDATE
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

-- Time capsules policies
CREATE POLICY "Couple members can view their capsules"
    ON time_capsules FOR SELECT
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Couple members can insert capsules"
    ON time_capsules FOR INSERT
    WITH CHECK (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

-- Function to create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id)
    VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create profile
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to tables
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_couples_updated_at
    BEFORE UPDATE ON couples
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_timeline_events_updated_at
    BEFORE UPDATE ON timeline_events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX idx_profiles_couple_id ON profiles(couple_id);
CREATE INDEX idx_profiles_partner_id ON profiles(partner_id);
CREATE INDEX idx_couples_invite_code ON couples(invite_code);
CREATE INDEX idx_timeline_events_couple_id ON timeline_events(couple_id);
CREATE INDEX idx_timeline_events_date ON timeline_events(date);
CREATE INDEX idx_time_capsules_couple_id ON time_capsules(couple_id);
CREATE INDEX idx_time_capsules_unlock_date ON time_capsules(unlock_date);
