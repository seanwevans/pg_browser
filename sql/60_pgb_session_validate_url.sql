CREATE OR REPLACE FUNCTION pgb_session.validate_url(p_url TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_url TEXT := trim(p_url);
BEGIN
    IF v_url IS NULL OR v_url = '' THEN
        RAISE EXCEPTION 'url must not be empty'
            USING ERRCODE = 'PGBUV';
    END IF;

    -- Enforce lowercase scheme and basic host/path structure.
    IF v_url !~ '^(pgb|https?)://[A-Za-z0-9.-]+(:[0-9]+)?(/[A-Za-z0-9._~!$&''()*+,;=:@%/-]*)?$' THEN
        RAISE EXCEPTION 'invalid URL: %', v_url
            USING ERRCODE = 'PGBUV';
    END IF;

    RETURN v_url;
END;
$$;

COMMENT ON FUNCTION pgb_session.validate_url(p_url TEXT) IS
    'Validate a URL ensuring it is not empty, trimmed, and uses an allowed scheme with a valid host/path. Returns the trimmed URL.';

