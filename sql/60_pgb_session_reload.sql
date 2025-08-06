CREATE OR REPLACE FUNCTION pgb_session.reload(p_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_url TEXT;
    next_n BIGINT;
BEGIN
    SELECT current_url INTO v_url
    FROM pgb_session.session
    WHERE id = p_session_id
    FOR UPDATE;

    IF v_url IS NULL THEN
        RAISE EXCEPTION 'session % not found', p_session_id
            USING ERRCODE = 'PGBSN';
    END IF;

    SELECT COALESCE(
            (
                SELECT n
                FROM pgb_session.history
                WHERE session_id = p_session_id
                ORDER BY n DESC
                LIMIT 1
            ),
            0
        ) + 1
    INTO next_n;

    INSERT INTO pgb_session.history(session_id, n, url)
    VALUES (p_session_id, next_n, v_url);
END;
$$;

COMMENT ON FUNCTION pgb_session.reload(p_session_id UUID) IS
    'Record a reload event. Parameters: p_session_id - session ID. Returns: void.';
