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
        WHERE session_id = sid AND url = 'pgb://local/demo'
    ) THEN
        RAISE EXCEPTION 'history row missing or incorrect';
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
        WHERE s.id = sid AND h.n = 2 AND h.url = s.current_url
    ) THEN
        RAISE EXCEPTION 'reload did not update history correctly';
    END IF;
END;
$$;

DO $$
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
