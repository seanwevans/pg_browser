-- Test concurrent navigations to ensure unique history entries
CREATE EXTENSION IF NOT EXISTS dblink;

-- Open a new session and capture the ID
SELECT pgb_session.open('pgb://local/demo') AS sid \gset

-- Establish two connections for concurrent navigations
SELECT dblink_connect('c1', 'dbname=' || current_database());
SELECT dblink_connect('c2', 'dbname=' || current_database());

-- Launch navigations concurrently
SELECT dblink_send_query('c1', format('SELECT pgb_session.navigate(''%s'', ''http://example.com/a'')', :'sid'));
SELECT dblink_send_query('c2', format('SELECT pgb_session.navigate(''%s'', ''http://example.com/b'')', :'sid'));

-- Wait for both navigations to complete
SELECT * FROM dblink_get_result('c1') AS t(result text);
SELECT * FROM dblink_get_result('c2') AS t(result text);

-- Verify history sequence numbers are unique and sequential
SELECT array_agg(n - min_n ORDER BY n) AS ns
FROM (
    SELECT n, min(n) OVER () AS min_n
    FROM pgb_session.history
    WHERE session_id = :'sid'
) s;

-- Verify snapshots recorded for each navigation (plus initial)
SELECT count(*) = 3 AS snapshot_count
FROM pgb_session.snapshot WHERE session_id = :'sid';

SELECT dblink_disconnect('c1');
SELECT dblink_disconnect('c2');
