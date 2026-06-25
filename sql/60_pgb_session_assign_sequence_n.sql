-- Assign a per-session sequential `n` to history and snapshot rows. Both tables
-- key on (session_id, n), so numbering restarts at 1 for every session instead
-- of sharing a global identity sequence. When a caller supplies `n` explicitly
-- the provided value is honored; otherwise the next value for the row's session
-- is used. A transaction-scoped advisory lock keyed by table and session
-- serializes concurrent inserts so the computed maximum cannot race (see the
-- per-session advisory-lock guidance in ROADMAP.md).
CREATE OR REPLACE FUNCTION pgb_session.assign_sequence_n()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_next BIGINT;
BEGIN
    IF NEW.n IS NULL THEN
        PERFORM pg_advisory_xact_lock(
            hashtextextended(
                TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME || '/' || NEW.session_id::text,
                0
            )
        );

        EXECUTE format(
            'SELECT COALESCE(MAX(n), 0) + 1 FROM %I.%I WHERE session_id = $1',
            TG_TABLE_SCHEMA, TG_TABLE_NAME
        )
        INTO v_next
        USING NEW.session_id;

        NEW.n := v_next;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION pgb_session.assign_sequence_n() IS
    'BEFORE INSERT trigger that assigns a per-session sequential `n` when the '
    'inserted row leaves `n` NULL. Used by pgb_session.history and pgb_session.snapshot.';

CREATE OR REPLACE TRIGGER history_assign_n
    BEFORE INSERT ON pgb_session.history
    FOR EACH ROW
    EXECUTE FUNCTION pgb_session.assign_sequence_n();

CREATE OR REPLACE TRIGGER snapshot_assign_n
    BEFORE INSERT ON pgb_session.snapshot
    FOR EACH ROW
    EXECUTE FUNCTION pgb_session.assign_sequence_n();
