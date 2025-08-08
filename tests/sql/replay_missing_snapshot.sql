-- Attempt to replay without a snapshot; should raise an error
DO $$
DECLARE
    sid UUID;
BEGIN
    sid := pgb_session.open('pgb://local/demo');
    DELETE FROM pgb_session.snapshot WHERE session_id = sid;
    BEGIN
        PERFORM pgb_session.replay(sid, now());
        RAISE EXCEPTION 'replay did not fail';
    EXCEPTION
        WHEN sqlstate 'PGBNS' THEN
            RAISE NOTICE 'snapshot error raised as expected';
        WHEN others THEN
            RAISE EXCEPTION 'unexpected error: %', SQLERRM;
    END;
END;
$$;
