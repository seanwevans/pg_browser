CREATE SCHEMA IF NOT EXISTS pgb_session;

CREATE TABLE IF NOT EXISTS pgb_session.session (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    current_url TEXT NOT NULL CONSTRAINT session_current_url_check CHECK (current_url ~ '^(pgb|https?)://'),
    state JSONB NOT NULL DEFAULT '{}'::jsonb,
    focus UUID
);

COMMENT ON TABLE pgb_session.session IS
    'Active sessions with their current URL and state.';
COMMENT ON COLUMN pgb_session.session.id IS
    'Unique identifier for the session.';
COMMENT ON COLUMN pgb_session.session.created_at IS
    'Timestamp when the session was created.';
COMMENT ON COLUMN pgb_session.session.current_url IS
    'Current URL for the session; must begin with pgb://, http://, or https://, and may include path, query, and fragment components.';
COMMENT ON COLUMN pgb_session.session.state IS
    'Arbitrary JSONB data representing the session state.';
COMMENT ON COLUMN pgb_session.session.focus IS
    'Identifier of the currently focused element, if any.';

CREATE TABLE IF NOT EXISTS pgb_session.history (
    session_id UUID NOT NULL REFERENCES pgb_session.session(id) ON DELETE CASCADE,
    n BIGINT NOT NULL,
    url TEXT NOT NULL,
    ts TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY(session_id, n)
);

COMMENT ON TABLE pgb_session.history IS
    'Navigation history entries for sessions.';
COMMENT ON COLUMN pgb_session.history.session_id IS
    'Owning session for this history entry.';
COMMENT ON COLUMN pgb_session.history.n IS
    'Sequential number of the history entry within a session, starting at 1 and '
    'assigned automatically by the pgb_session.assign_sequence_n trigger when left NULL.';
COMMENT ON COLUMN pgb_session.history.url IS
    'URL that was visited.';
COMMENT ON COLUMN pgb_session.history.ts IS
    'Timestamp when the URL was recorded.';

CREATE TABLE IF NOT EXISTS pgb_session.snapshot (
    session_id UUID NOT NULL REFERENCES pgb_session.session(id) ON DELETE CASCADE,
    n BIGINT NOT NULL,
    ts TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    state JSONB NOT NULL,
    current_url TEXT NOT NULL,
    focus UUID,
    PRIMARY KEY(session_id, n)
);

COMMENT ON TABLE pgb_session.snapshot IS
    'Stored snapshots of session state used for replay.';
COMMENT ON COLUMN pgb_session.snapshot.session_id IS
    'Session associated with this snapshot.';
COMMENT ON COLUMN pgb_session.snapshot.n IS
    'Sequential identifier for the snapshot within a session, starting at 1 and '
    'assigned automatically by the pgb_session.assign_sequence_n trigger when left NULL.';
COMMENT ON COLUMN pgb_session.snapshot.ts IS
    'Timestamp when the snapshot was taken.';
COMMENT ON COLUMN pgb_session.snapshot.state IS
    'Session state captured at the snapshot time.';
COMMENT ON COLUMN pgb_session.snapshot.current_url IS
    'URL that was current when the snapshot was taken.';
COMMENT ON COLUMN pgb_session.snapshot.focus IS
    'Identifier of the currently focused element, if any.';

\ir 60_pgb_session_assign_sequence_n.sql

\ir 60_pgb_session_validate_url.sql
\ir 60_pgb_session_open.sql

CREATE OR REPLACE FUNCTION pgb_session.navigate(p_session_id UUID, p_url TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    p_url := pgb_session.validate_url(p_url);

    UPDATE pgb_session.session
    SET current_url = p_url
    WHERE id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'session % not found', p_session_id
            USING ERRCODE = 'PGBSN';
    END IF;

    INSERT INTO pgb_session.history(session_id, url, ts)
    VALUES (p_session_id, p_url, clock_timestamp());

    -- Record a snapshot after navigation to capture the new URL and state
    INSERT INTO pgb_session.snapshot(session_id, state, current_url, focus)
    SELECT id, state, current_url, focus
    FROM pgb_session.session
    WHERE id = p_session_id;
END;
$$;

COMMENT ON FUNCTION pgb_session.navigate(p_session_id UUID, p_url TEXT) IS
    'Navigate to a new URL and record a snapshot. Parameters: p_session_id - session ID; p_url - destination URL. Returns: void.';


\ir 60_pgb_session_reload.sql
\ir 60_pgb_session_replay.sql

CREATE OR REPLACE FUNCTION pgb_session.close(p_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM pgb_session.session
    WHERE id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'session % not found', p_session_id
            USING ERRCODE = 'PGBSN';
    END IF;
END;
$$;

COMMENT ON FUNCTION pgb_session.close(p_session_id UUID) IS
    'Close a session and remove all associated data. Raises SQLSTATE PGBSN if the session does not exist. Parameters: p_session_id - session ID. Returns: void.';
