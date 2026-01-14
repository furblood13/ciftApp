-- Delete Couple Function
-- This function permanently deletes a couple and all related data for both users
-- Based on actual schema analysis from Database folder

CREATE OR REPLACE FUNCTION delete_couple(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_couple_id UUID;
    v_partner_id UUID;
BEGIN
    -- Get the user's couple_id and partner_id
    SELECT couple_id, partner_id INTO v_couple_id, v_partner_id
    FROM profiles
    WHERE id = p_user_id;
    
    -- Check if user is in a couple
    IF v_couple_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Not in a couple');
    END IF;
    
    -- Delete all timeline events for the couple
    -- (timeline_events has couple_id column)
    DELETE FROM timeline_events 
    WHERE couple_id = v_couple_id;
    
    -- Delete all todos for the couple
    -- (todos has couple_id column)
    DELETE FROM todos 
    WHERE couple_id = v_couple_id;
    
    -- Delete all time capsules for the couple
    -- (time_capsules has couple_id column)
    DELETE FROM time_capsules 
    WHERE couple_id = v_couple_id;
    
    -- Clear partner references from both profiles
    UPDATE profiles
    SET couple_id = NULL, partner_id = NULL
    WHERE id = p_user_id OR id = v_partner_id;
    
    -- Delete the couple record
    DELETE FROM couples
    WHERE id = v_couple_id;
    
    RETURN json_build_object('success', true);
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;
