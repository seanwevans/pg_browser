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
