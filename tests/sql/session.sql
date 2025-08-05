-- Install core dependencies
\ir ../../sql/00_install.sql
\ir ../../sql/60_pgb_session.sql

SET TIME ZONE 'UTC';
SET datestyle TO ISO, YMD;

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

-- Accept valid URL schemes
SELECT pgb_session.open('http://example.com') IS NOT NULL AS http_opened;
SELECT pgb_session.open('https://example.com') IS NOT NULL AS https_opened;

-- Accept uppercase URL schemes
SELECT pgb_session.open('HTTP://example.com') IS NOT NULL AS http_upper_opened;
SELECT pgb_session.open('HTTPS://example.com') IS NOT NULL AS https_upper_opened;

-- Reject invalid URL scheme
SELECT pgb_session.open('ftp://example.com');

-- Reject invalid URL scheme on direct insert
INSERT INTO pgb_session.session(id, created_at, current_url)
VALUES ('00000000-0000-0000-0000-000000000000', '2000-01-01 00:00:00+00', 'ftp://example.com');

-- Ensure empty URL raises an exception
SELECT pgb_session.open('');
