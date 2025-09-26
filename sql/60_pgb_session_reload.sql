CREATE OR REPLACE FUNCTION pgb_session.reload(p_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_url TEXT;
    v_state JSONB;
    v_focus UUID;
BEGIN
    SELECT current_url, state, focus INTO v_url, v_state, v_focus
    FROM pgb_session.session
    WHERE id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'session % not found', p_session_id
            USING ERRCODE = 'PGBSN';
    END IF;

    INSERT INTO pgb_session.history(session_id, url, ts)
    VALUES (p_session_id, v_url, clock_timestamp());

    -- Capture a snapshot of the session at reload time
    INSERT INTO pgb_session.snapshot(session_id, state, current_url, focus)
    VALUES (p_session_id, v_state, v_url, v_focus);
END;
$$;

COMMENT ON FUNCTION pgb_session.reload(p_session_id UUID) IS
    'Record a reload event and snapshot the session. Parameters: p_session_id - session ID. Returns: void.';
