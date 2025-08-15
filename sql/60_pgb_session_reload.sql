CREATE OR REPLACE FUNCTION pgb_session.reload(p_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_url TEXT;
BEGIN
    SELECT current_url INTO v_url
    FROM pgb_session.session
    WHERE id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'session % not found', p_session_id
            USING ERRCODE = 'PGBSN';
    END IF;

    INSERT INTO pgb_session.history(session_id, url, ts)
    VALUES (p_session_id, v_url, clock_timestamp());
END;
$$;

COMMENT ON FUNCTION pgb_session.reload(p_session_id UUID) IS
    'Record a reload event. Raises SQLSTATE PGBSN if the session does not exist. Parameters: p_session_id - session ID. Returns: void.';
