CREATE SCHEMA IF NOT EXISTS pgb_session;

CREATE TABLE IF NOT EXISTS pgb_session.session (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    current_url TEXT NOT NULL CONSTRAINT session_current_url_check CHECK (current_url ~* '^(pgb|https?)://'),
    state JSONB NOT NULL DEFAULT '{}'::jsonb,
    focus UUID
);

CREATE TABLE IF NOT EXISTS pgb_session.history (
    session_id UUID NOT NULL REFERENCES pgb_session.session(id) ON DELETE CASCADE,
    n BIGINT NOT NULL,
    url TEXT NOT NULL,
    ts TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY(session_id, n)
);

CREATE OR REPLACE FUNCTION pgb_session.open(p_url TEXT)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    sid UUID;
BEGIN
    IF p_url IS NULL OR p_url = '' THEN
        RAISE EXCEPTION 'url must not be empty';
    END IF;

    IF p_url !~* '^(pgb|https?)://' THEN
        RAISE EXCEPTION 'unsupported URL scheme: %', p_url;
    END IF;

    INSERT INTO pgb_session.session(current_url)
    VALUES (p_url)
    RETURNING id INTO sid;

    INSERT INTO pgb_session.history(session_id, n, url)
    VALUES (sid, 1, p_url);

    RETURN sid;
END;
$$;

COMMENT ON FUNCTION pgb_session.open(p_url TEXT) IS
    'Open a new session. Parameters: p_url - initial URL. Returns: session UUID.';

CREATE OR REPLACE FUNCTION pgb_session.reload(p_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_url TEXT;
    next_n BIGINT;
BEGIN
    SELECT current_url INTO v_url
    FROM pgb_session.session
    WHERE id = p_session_id
    FOR UPDATE;

    IF v_url IS NULL THEN
        RAISE EXCEPTION 'session % not found', p_session_id
            USING ERRCODE = 'PGBSN';
    END IF;

    SELECT COALESCE(max(n), 0) + 1
    INTO next_n
    FROM pgb_session.history
    WHERE session_id = p_session_id;

    INSERT INTO pgb_session.history(session_id, n, url)
    VALUES (p_session_id, next_n, v_url);
END;
$$;

COMMENT ON FUNCTION pgb_session.reload(p_session_id UUID) IS
    'Record a reload event. Parameters: p_session_id - session ID. Returns: void.';

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
    'Close and delete a session. Parameters: p_session_id - session ID. Deletes session and history via cascade. Returns: void.';
