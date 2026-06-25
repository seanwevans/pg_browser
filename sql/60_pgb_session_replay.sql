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

    -- Identify the latest history entry that should remain after replay.
    DELETE FROM pgb_session.history
    WHERE session_id = p_session_id
      AND n > COALESCE((
          SELECT h.n
          FROM pgb_session.history h
          WHERE h.session_id = p_session_id
            AND (
                h.ts < v_snap_ts
                OR (h.ts = v_snap_ts AND h.url = v_url)
            )
          ORDER BY h.n DESC
          LIMIT 1
      ), 0);

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
