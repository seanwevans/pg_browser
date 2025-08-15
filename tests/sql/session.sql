-- Install core dependencies
\ir ../../sql/00_install.sql
\ir ../../sql/60_pgb_session.sql

SET TIME ZONE 'UTC';
SET datestyle TO ISO, YMD;

-- Open a new session and capture the ID
SELECT pgb_session.open('pgb://local/demo') AS sid \gset

-- Ensure an ID is returned
SELECT :'sid' IS NOT NULL AS opened;

-- Verify snapshot inserted with initial state and URL
SELECT count(*) = 1 AS snapshot_created
FROM pgb_session.snapshot WHERE session_id = :'sid';
SELECT state = '{}'::jsonb AND current_url = 'pgb://local/demo' AS snapshot_matches
FROM pgb_session.snapshot WHERE session_id = :'sid';

-- Reload the session
SELECT pgb_session.reload(:'sid');

-- Verify session table has one row
SELECT count(*) AS session_count FROM pgb_session.session;

-- Verify history table has two entries
SELECT count(*) AS history_count FROM pgb_session.history;

-- Verify snapshot recorded on reload
SELECT count(*) = 2 AS snapshot_count_after_reload
FROM pgb_session.snapshot WHERE session_id = :'sid';


-- Navigate to new URLs within the session
SELECT pgb_session.navigate(:'sid', 'http://example.com');
SELECT pgb_session.navigate(:'sid', 'https://example.org');

-- Verify current_url updated
SELECT current_url = 'https://example.org' AS navigated
FROM pgb_session.session WHERE id = :'sid';

-- Verify history table has four entries for the session
SELECT count(*) AS history_count_after_nav FROM pgb_session.history WHERE session_id = :'sid';

-- Verify snapshots recorded on navigations
SELECT count(*) = 4 AS snapshot_count_after_nav
FROM pgb_session.snapshot WHERE session_id = :'sid';

-- Verify latest snapshot matches current URL
SELECT current_url = 'https://example.org' AS snapshot_latest_url
FROM pgb_session.snapshot WHERE session_id = :'sid' ORDER BY ts DESC LIMIT 1;

-- Verify history numbering is sequential
SELECT (
    SELECT n FROM pgb_session.history WHERE session_id = :'sid' ORDER BY n DESC LIMIT 1
) = count(*) AS sequential
FROM pgb_session.history WHERE session_id = :'sid';

-- Verify history timestamps increase with navigation order
SELECT bool_and(ts > lag_ts) AS ts_ordered
FROM (
    SELECT ts, lag(ts) OVER (ORDER BY n) AS lag_ts
    FROM pgb_session.history WHERE session_id = :'sid'
) s WHERE lag_ts IS NOT NULL;

-- Reject invalid URL scheme on navigate
DO $$
DECLARE
    v_sid UUID;
BEGIN
    SELECT id INTO v_sid FROM pgb_session.session LIMIT 1;

    BEGIN
        PERFORM pgb_session.navigate(v_sid, 'ftp://example.com');
        RAISE EXCEPTION 'navigate did not fail';
    EXCEPTION
        WHEN sqlstate 'PGBUV' THEN
            RAISE NOTICE 'error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;
END;
$$;

-- Close the session
SELECT pgb_session.close(:'sid');

-- Verify session and history cleared
SELECT count(*) AS session_count_after_close FROM pgb_session.session;
SELECT count(*) AS history_count_after_close FROM pgb_session.history;


-- Accept valid URL schemes
SELECT pgb_session.open('http://example.com') IS NOT NULL AS http_opened;
SELECT pgb_session.open('https://example.com') IS NOT NULL AS https_opened;

-- Trim surrounding whitespace
SELECT pgb_session.open(' http://example.com ') IS NOT NULL AS http_whitespace_opened;

-- Accept URLs with query and fragment components
SELECT pgb_session.open('http://example.com/path?foo=bar') IS NOT NULL AS http_query_opened;
SELECT pgb_session.open('http://example.com/path?foo=bar#frag') IS NOT NULL AS http_query_fragment_opened;
SELECT pgb_session.open('http://example.com/path#frag') IS NOT NULL AS http_fragment_opened;

-- Reject malformed query/fragment URLs
SELECT pgb_session.open('http://example.com/path#frag?bad');

-- Reject uppercase URL schemes
SELECT pgb_session.open('HTTP://example.com');
SELECT pgb_session.open('HTTPS://example.com');

-- Reject invalid URL scheme
DO $$
BEGIN
    BEGIN
        PERFORM pgb_session.open('ftp://example.com');
        RAISE EXCEPTION 'open did not fail';
    EXCEPTION
        WHEN sqlstate 'PGBUV' THEN
            RAISE NOTICE 'error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;
END;
$$;

-- Reject malformed URLs
SELECT pgb_session.open('http:///missinghost');

-- Reject invalid URL scheme on direct insert
DO $$
BEGIN
    BEGIN
        INSERT INTO pgb_session.session(id, created_at, current_url)
        VALUES ('00000000-0000-0000-0000-000000000000', '2000-01-01 00:00:00+00', 'ftp://example.com');
        RAISE EXCEPTION 'insert did not fail';
    EXCEPTION
        WHEN sqlstate '23514' THEN
            RAISE NOTICE 'error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;
END;
$$;

-- Reject uppercase URL scheme on direct insert
DO $$
BEGIN
    BEGIN
        INSERT INTO pgb_session.session(id, created_at, current_url)
        VALUES ('00000000-0000-0000-0000-000000000001', '2000-01-01 00:00:00+00', 'HTTP://example.com');
        RAISE EXCEPTION 'insert did not fail';
    EXCEPTION
        WHEN sqlstate '23514' THEN
            RAISE NOTICE 'error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;

    BEGIN
        INSERT INTO pgb_session.session(id, created_at, current_url)
        VALUES ('00000000-0000-0000-0000-000000000002', '2000-01-01 00:00:00+00', 'HTTPS://example.com');
        RAISE EXCEPTION 'insert did not fail';
    EXCEPTION
        WHEN sqlstate '23514' THEN
            RAISE NOTICE 'error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;
END;
$$;

-- Ensure empty URL raises an exception
DO $$
BEGIN
    BEGIN
        PERFORM pgb_session.open('');
        RAISE EXCEPTION 'open did not fail';
    EXCEPTION
        WHEN sqlstate 'PGBUV' THEN
            RAISE NOTICE 'error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;
END;
$$;

-- Validate URLs directly using helper
SELECT pgb_session.validate_url('http://example.com');
DO $$
BEGIN
    BEGIN
        PERFORM pgb_session.validate_url('ftp://example.com');
        RAISE EXCEPTION 'validation did not fail';
    EXCEPTION
        WHEN sqlstate 'PGBUV' THEN
            RAISE NOTICE 'error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;
END;
$$;
DO $$
BEGIN
    BEGIN
        PERFORM pgb_session.validate_url('');
        RAISE EXCEPTION 'validation did not fail';
    EXCEPTION
        WHEN sqlstate 'PGBUV' THEN
            RAISE NOTICE 'error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;
END;
$$;
