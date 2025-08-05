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

\ir 60_pgb_session_reload.sql
