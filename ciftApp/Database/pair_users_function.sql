-- =====================================================
-- PAIR_USERS Function
-- This function runs with elevated privileges to update both profiles
-- Run this in Supabase SQL Editor
-- =====================================================

CREATE OR REPLACE FUNCTION pair_users(
    p_invite_code TEXT,
    p_joiner_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_couple RECORD;
    v_creator_id UUID;
    v_joiner_partner_id UUID;
    v_result JSON;
BEGIN
    -- Check if joiner already has a partner
    SELECT partner_id INTO v_joiner_partner_id
    FROM profiles
    WHERE id = p_joiner_id;
    
    IF v_joiner_partner_id IS NOT NULL THEN
        RETURN json_build_object('success', false, 'error', 'Already have a partner');
    END IF;
    
    -- Find couple by invite code
    SELECT id, creator_id INTO v_couple
    FROM couples
    WHERE invite_code = UPPER(p_invite_code);
    
    IF v_couple.id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Invalid code');
    END IF;
    
    v_creator_id := v_couple.creator_id;
    
    -- Can't use own code
    IF v_creator_id = p_joiner_id THEN
        RETURN json_build_object('success', false, 'error', 'Cannot use own code');
    END IF;
    
    -- Update joiner's profile
    UPDATE profiles
    SET couple_id = v_couple.id,
        partner_id = v_creator_id,
        updated_at = NOW()
    WHERE id = p_joiner_id;
    
    -- Update creator's profile
    UPDATE profiles
    SET couple_id = v_couple.id,
        partner_id = p_joiner_id,
        updated_at = NOW()
    WHERE id = v_creator_id;
    
    -- Update couple start_date
    UPDATE couples
    SET start_date = CURRENT_DATE,
        updated_at = NOW()
    WHERE id = v_couple.id;
    
    RETURN json_build_object(
        'success', true,
        'couple_id', v_couple.id,
        'partner_id', v_creator_id
    );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION pair_users(TEXT, UUID) TO authenticated;
