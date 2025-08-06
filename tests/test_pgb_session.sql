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
        WHERE session_id = sid AND url = 'pgb://local/demo'
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


    PERFORM pgb_session.navigate(sid, 'http://example.com');
    IF NOT EXISTS (
        SELECT 1 FROM pgb_session.session
        WHERE id = sid AND current_url = 'http://example.com'
    ) THEN
        RAISE EXCEPTION 'navigate did not update current_url';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pgb_session.history
        WHERE session_id = sid AND n = 2 AND url = 'http://example.com'
    ) THEN
        RAISE EXCEPTION 'history row missing after first navigate';
    END IF;

    PERFORM pgb_session.navigate(sid, 'https://example.org');
    IF NOT EXISTS (
        SELECT 1 FROM pgb_session.session
        WHERE id = sid AND current_url = 'https://example.org'
    ) THEN
        RAISE EXCEPTION 'navigate did not update current_url to second url';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pgb_session.history
        WHERE session_id = sid AND n = 3 AND url = 'https://example.org'
    ) THEN
        RAISE EXCEPTION 'history row missing after second navigate';
    END IF;

    IF (
        SELECT n FROM pgb_session.history
        WHERE session_id = sid
        ORDER BY n DESC
        LIMIT 1
    ) <> 3 THEN
        RAISE EXCEPTION 'navigate did not produce sequential numbering';
    END IF;


    PERFORM pgb_session.reload(sid);

    IF NOT EXISTS (
        SELECT 1
        FROM pgb_session.session s
        JOIN LATERAL (
            SELECT n, url FROM pgb_session.history h
            WHERE h.session_id = s.id
            ORDER BY h.n DESC
            LIMIT 1
        ) h ON true
        WHERE s.id = sid AND h.n = 4 AND h.url = s.current_url
    ) THEN
        RAISE EXCEPTION 'reload did not update history correctly';
    END IF;


    IF (
        SELECT n FROM pgb_session.history
        WHERE session_id = sid
        ORDER BY n DESC
        LIMIT 1
    ) <> 4 THEN
        RAISE EXCEPTION 'reload did not produce sequential numbering';
    END IF;


DO $$
DECLARE
    sid2 UUID;
BEGIN

    BEGIN
        PERFORM pgb_session.reload(gen_random_uuid());
        RAISE EXCEPTION 'reload did not fail';
    EXCEPTION
        WHEN sqlstate 'PGBSN' THEN
            RAISE NOTICE 'error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;

    BEGIN
        PERFORM pgb_session.replay(gen_random_uuid(), clock_timestamp());
        RAISE EXCEPTION 'replay did not fail';
    EXCEPTION
        WHEN sqlstate 'PGBSN' THEN
            RAISE NOTICE 'session error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;

    sid2 := pgb_session.open('pgb://local/tmp');
    BEGIN
        PERFORM pgb_session.replay(sid2, clock_timestamp());
        RAISE EXCEPTION 'replay did not fail';
    EXCEPTION
        WHEN sqlstate 'PGBNS' THEN
            RAISE NOTICE 'snapshot error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;
    PERFORM pgb_session.close(sid2);

    PERFORM pgb_session.close(sid);

    IF EXISTS (
        SELECT 1 FROM pgb_session.session WHERE id = sid
    ) THEN
        RAISE EXCEPTION 'session row not deleted';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pgb_session.history WHERE session_id = sid
    ) THEN
        RAISE EXCEPTION 'history rows not deleted';
    END IF;

    
END;
$$;

ROLLBACK;
