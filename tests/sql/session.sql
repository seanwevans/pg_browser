-- Install core dependencies
\ir ../../sql/00_install.sql
\ir ../../sql/60_pgb_session.sql

-- Open a new session and capture the ID
SELECT pgb_session.open('pgb://local/demo') AS sid \gset

-- Ensure an ID is returned
SELECT :'sid' IS NOT NULL AS opened;

-- Reload the session
SELECT pgb_session.reload(:'sid');

-- Verify session table has one row
SELECT count(*) AS session_count FROM pgb_session.session;

-- Verify history table has two entries
SELECT count(*) AS history_count FROM pgb_session.history;

-- Ensure empty URL raises an exception
SELECT pgb_session.open('');
