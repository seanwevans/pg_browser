CREATE OR REPLACE FUNCTION pgb_session.validate_url(p_url TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_url IS NULL OR p_url = '' THEN
        RAISE EXCEPTION 'url must not be empty'
            USING ERRCODE = 'PGBUV';
    END IF;

    IF p_url !~* '^(pgb|https?)://' THEN
        RAISE EXCEPTION 'unsupported URL scheme: %', p_url
            USING ERRCODE = 'PGBUV';
    END IF;
END;
$$;

COMMENT ON FUNCTION pgb_session.validate_url(p_url TEXT) IS
    'Validate a URL ensuring it is not empty and uses an allowed scheme.';

