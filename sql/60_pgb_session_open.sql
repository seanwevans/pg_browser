CREATE OR REPLACE FUNCTION pgb_session.open(p_url TEXT)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    sid UUID;
    session_state JSONB;
    session_url TEXT;
    session_focus UUID;
BEGIN
    p_url := pgb_session.validate_url(p_url);

    INSERT INTO pgb_session.session(current_url)
    VALUES (p_url)
    RETURNING id, state, current_url, focus INTO sid, session_state, session_url, session_focus;

    -- Record the history entry before the snapshot so that, as with navigate()
    -- and reload(), a snapshot's timestamp is never earlier than the history
    -- entry it corresponds to. replay() relies on this ordering when pruning.
    INSERT INTO pgb_session.history(session_id, url)
    VALUES (sid, p_url);

    INSERT INTO pgb_session.snapshot(session_id, state, current_url, focus)
    VALUES (sid, session_state, session_url, session_focus);

    RETURN sid;
END;
$$;

COMMENT ON FUNCTION pgb_session.open(p_url TEXT) IS
    'Open a new session. Raises SQLSTATE PGBUV if the initial URL is invalid. Parameters: p_url - initial URL. Returns: session UUID.';
