-- =====================================================
-- Us & Time - Shared Todos Migration
-- Phase 19: Ortak Yapılacaklar Listesi
-- =====================================================

-- Todos table
CREATE TABLE todos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID REFERENCES couples(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    is_completed BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES profiles(id),
    completed_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Enable RLS
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Couple members can view todos"
    ON todos FOR SELECT
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Couple members can insert todos"
    ON todos FOR INSERT
    WITH CHECK (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Couple members can update todos"
    ON todos FOR UPDATE
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Couple members can delete todos"
    ON todos FOR DELETE
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

-- Index for faster queries
CREATE INDEX idx_todos_couple_id ON todos(couple_id);
CREATE INDEX idx_todos_created_at ON todos(created_at DESC);
