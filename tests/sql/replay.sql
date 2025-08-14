-- Install core dependencies
\ir ../../sql/00_install.sql
\ir ../../sql/60_pgb_session.sql

SET TIME ZONE 'UTC';
SET datestyle TO ISO, YMD;

-- Open a new session and capture the ID
SELECT pgb_session.open('pgb://local/demo') AS sid \gset

-- Snapshot current state and capture timestamp
INSERT INTO pgb_session.snapshot(session_id, ts, state, current_url)
SELECT :'sid', now(), state, current_url
FROM pgb_session.session WHERE id = :'sid'
RETURNING ts AS snap_ts \gset

-- Mutate session and history
UPDATE pgb_session.session SET current_url = 'pgb://local/other', state = '{"foo":"bar"}' WHERE id = :'sid';
INSERT INTO pgb_session.history(session_id, n, url)
VALUES (:'sid', 2, 'pgb://local/other');

-- Take a snapshot of the mutated state to ensure replay cleans it up
INSERT INTO pgb_session.snapshot(session_id, state, current_url)
SELECT :'sid', state, current_url
FROM pgb_session.session WHERE id = :'sid'
RETURNING ts AS future_ts \gset

-- Verify state before replay
SELECT current_url, state FROM pgb_session.session WHERE id = :'sid';
SELECT count(*) AS history_count_before FROM pgb_session.history WHERE session_id = :'sid';

-- Replay to snapshot timestamp
SELECT pgb_session.replay(:'sid', :'snap_ts');

-- Verify restored state and history
SELECT current_url, state FROM pgb_session.session WHERE id = :'sid';
SELECT count(*) AS history_count_after FROM pgb_session.history WHERE session_id = :'sid';
SELECT url FROM pgb_session.history WHERE session_id = :'sid' ORDER BY n;
SELECT count(*) AS future_snapshot_exists FROM pgb_session.snapshot WHERE session_id = :'sid' AND ts = :'future_ts';
SELECT count(*) AS snapshots_newer_after FROM pgb_session.snapshot WHERE session_id = :'sid' AND ts > :'snap_ts';
SELECT state, current_url FROM pgb_session.snapshot WHERE session_id = :'sid' ORDER BY ts;
