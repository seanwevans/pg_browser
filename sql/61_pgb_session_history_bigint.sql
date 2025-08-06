ALTER TABLE pgb_session.history
    ALTER COLUMN n DROP IDENTITY IF EXISTS,
    ALTER COLUMN n TYPE BIGINT;

\ir 60_pgb_session_open.sql

\ir 60_pgb_session_reload.sql
