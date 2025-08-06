-- Attempt to replay without a snapshot; should raise an error
DO $$
DECLARE
    sid UUID;
BEGIN
    sid := pgb_session.open('pgb://local/demo');
    BEGIN
        PERFORM pgb_session.replay(sid, now());
        RAISE EXCEPTION 'replay did not fail';
    EXCEPTION
        WHEN sqlstate 'PGBSN' THEN
            RAISE NOTICE 'error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;
END;
$$;
