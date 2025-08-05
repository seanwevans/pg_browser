DO $$
BEGIN
    ALTER TABLE pgb_session.session
        ADD CONSTRAINT session_current_url_check
        CHECK (current_url ~* '^(pgb|https?)://');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
