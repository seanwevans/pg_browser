CREATE OR REPLACE FUNCTION pgb_session.open(p_url TEXT)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    sid UUID;
BEGIN
    p_url := trim(p_url);
    PERFORM pgb_session.validate_url(p_url);

    INSERT INTO pgb_session.session(current_url)
    VALUES (p_url)
    RETURNING id INTO sid;

    INSERT INTO pgb_session.history(session_id, n, url)
    VALUES (sid, 1, p_url);

    RETURN sid;
END;
$$;

COMMENT ON FUNCTION pgb_session.open(p_url TEXT) IS
    'Open a new session. Parameters: p_url - initial URL. Returns: session UUID.';
