\set ON_ERROR_STOP on

BEGIN;
\i sql/00_install.sql
\i sql/60_pgb_session.sql

DO $$
DECLARE
    sid UUID;
    snap_ts TIMESTAMPTZ;
BEGIN
    sid := pgb_session.open('pgb://local/demo');
    IF sid IS NULL THEN
        RAISE EXCEPTION 'pgb_session.open returned NULL';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pgb_session.session
        WHERE id = sid AND current_url = 'pgb://local/demo'
    ) THEN
        RAISE EXCEPTION 'session row missing or incorrect';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pgb_session.history
        WHERE session_id = sid AND n = 1 AND url = 'pgb://local/demo'
    ) THEN
        RAISE EXCEPTION 'history row missing or incorrect';
    END IF;

    -- Snapshot current state and record timestamp
    snap_ts := clock_timestamp();
    INSERT INTO pgb_session.snapshot(session_id, ts, state, current_url)
    SELECT sid, snap_ts, state, current_url
    FROM pgb_session.session
    WHERE id = sid;

    -- Mutate session and history
    UPDATE pgb_session.session
    SET current_url = 'pgb://local/other', state = '{"foo":"bar"}'
    WHERE id = sid;
    INSERT INTO pgb_session.history(session_id, n, url, ts)
    VALUES (sid, 2, 'pgb://local/other', clock_timestamp());

    -- Replay to snapshot
    PERFORM pgb_session.replay(sid, snap_ts);

    -- Ensure session state restored
    IF NOT EXISTS (
        SELECT 1 FROM pgb_session.session
        WHERE id = sid
          AND current_url = 'pgb://local/demo'
          AND state = '{}'::jsonb
    ) THEN
        RAISE EXCEPTION 'replay did not restore session';
    END IF;

    -- Ensure history truncated
    IF EXISTS (
        SELECT 1 FROM pgb_session.history
        WHERE session_id = sid AND n > 1
    ) THEN
        RAISE EXCEPTION 'replay did not truncate history';
    END IF;
END;
$$;

ROLLBACK;
