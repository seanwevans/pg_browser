ALTER TABLE pgb_session.history
    ALTER COLUMN n TYPE BIGINT;

\ir 60_pgb_session_reload.sql
