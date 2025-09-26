ALTER TABLE pgb_session.snapshot
    ADD COLUMN IF NOT EXISTS focus UUID;

COMMENT ON COLUMN pgb_session.snapshot.focus IS
    'Identifier of the currently focused element, if any.';

\ir 60_pgb_session_open.sql
\ir 60_pgb_session_reload.sql

CREATE OR REPLACE FUNCTION pgb_session.navigate(p_session_id UUID, p_url TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    p_url := pgb_session.validate_url(p_url);

    UPDATE pgb_session.session
    SET current_url = p_url
    WHERE id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'session % not found', p_session_id
            USING ERRCODE = 'PGBSN';
    END IF;

    INSERT INTO pgb_session.history(session_id, url, ts)
    VALUES (p_session_id, p_url, clock_timestamp());

    -- Record a snapshot after navigation to capture the new URL and state
    INSERT INTO pgb_session.snapshot(session_id, state, current_url, focus)
    SELECT id, state, current_url, focus
    FROM pgb_session.session
    WHERE id = p_session_id;
END;
$$;

COMMENT ON FUNCTION pgb_session.navigate(p_session_id UUID, p_url TEXT) IS
    'Navigate to a new URL and record a snapshot. Parameters: p_session_id - session ID; p_url - destination URL. Returns: void.';

CREATE OR REPLACE FUNCTION pgb_session.replay(p_session_id UUID, p_ts TIMESTAMPTZ)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_state JSONB;
    v_url TEXT;
    v_focus UUID;
    v_snap_ts TIMESTAMPTZ;
BEGIN
    -- Acquire a lock on the session row to ensure consistency for
    -- subsequent updates and deletes.
    PERFORM 1
    FROM pgb_session.session
    WHERE id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'session % not found', p_session_id
            USING ERRCODE = 'PGBSN';
    END IF;

    SELECT state, current_url, focus, ts
    INTO v_state, v_url, v_focus, v_snap_ts
    FROM pgb_session.snapshot
    WHERE session_id = p_session_id
      AND ts <= p_ts
    ORDER BY ts DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'snapshot not found for session % at %', p_session_id, p_ts
            USING ERRCODE = 'PGBNS';
    END IF;

    UPDATE pgb_session.session
    SET state = v_state,
        current_url = v_url,
        focus = v_focus
    WHERE id = p_session_id;

    DELETE FROM pgb_session.history
    WHERE session_id = p_session_id
      AND ts > v_snap_ts;

    -- Remove snapshots taken after the target snapshot
    DELETE FROM pgb_session.snapshot
    WHERE session_id = p_session_id
      AND ts > v_snap_ts;

    -- Record a new snapshot of the restored state
    INSERT INTO pgb_session.snapshot(session_id, state, current_url, focus)
    VALUES (p_session_id, v_state, v_url, v_focus);
END;
$$;

COMMENT ON FUNCTION pgb_session.replay(p_session_id UUID, p_ts TIMESTAMPTZ) IS
    'Rewind a session to a snapshot at or before p_ts. Raises SQLSTATE PGBSN if the session does not exist and PGBNS if no snapshot is found. Parameters: p_session_id - session ID; p_ts - target timestamp. Example usage: SELECT pgb_session.replay(:session_id, ''2025-08-04T15:30:00Z''::timestamptz); Returns: void.';
