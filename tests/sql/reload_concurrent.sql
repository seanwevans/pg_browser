-- Test concurrent reloads to ensure unique history entries
CREATE EXTENSION IF NOT EXISTS dblink;

-- Open a new session and capture the ID
SELECT pgb_session.open('pgb://local/demo') AS sid \gset

-- Establish two connections for concurrent reloads
SELECT dblink_connect('c1', 'dbname=' || current_database());
SELECT dblink_connect('c2', 'dbname=' || current_database());

-- Launch reloads concurrently
SELECT dblink_send_query('c1', format('SELECT pgb_session.reload(''%s'')', :'sid'));
SELECT dblink_send_query('c2', format('SELECT pgb_session.reload(''%s'')', :'sid'));

-- Wait for both reloads to complete
SELECT * FROM dblink_get_result('c1') AS t(result text);
SELECT * FROM dblink_get_result('c2') AS t(result text);

-- Verify history sequence numbers are unique and sequential
SELECT array_agg(n ORDER BY n) AS ns FROM pgb_session.history WHERE session_id = :'sid';

SELECT dblink_disconnect('c1');
SELECT dblink_disconnect('c2');
