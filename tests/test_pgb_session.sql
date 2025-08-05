\set ON_ERROR_STOP on

BEGIN;
\i sql/00_install.sql
\i sql/60_pgb_session.sql

DO $$
DECLARE
    sid UUID;
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
END;
$$;

ROLLBACK;
