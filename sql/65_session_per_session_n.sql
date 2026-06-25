-- Convert pgb_session.history.n and pgb_session.snapshot.n from a global identity
-- sequence to per-session sequential numbering assigned by the
-- pgb_session.assign_sequence_n trigger.
--
-- Earlier installations numbered both tables with a single GENERATED ... AS
-- IDENTITY sequence, so `n` was unique across all sessions rather than the
-- per-session ordinal documented for the column (and relied on by replay()).
-- This migration drops the identity, renumbers existing rows per session in
-- timestamp order, attaches the trigger, and makes (session_id, n) the snapshot
-- primary key. It is safe to run on installations that already use the
-- per-session scheme (it re-derives the same numbering) and on fresh installs
-- created by the current 60_pgb_session.sql.

-- 1. Per-session numbering helper and its BEFORE INSERT triggers.
\ir 60_pgb_session_assign_sequence_n.sql

-- 2. history: drop any global identity, renumber per session, restore the key.
ALTER TABLE pgb_session.history
    ALTER COLUMN n DROP IDENTITY IF EXISTS;

ALTER TABLE pgb_session.history
    DROP CONSTRAINT IF EXISTS history_pkey;

WITH renum AS (
    SELECT ctid, row_number() OVER (PARTITION BY session_id ORDER BY ts, n) AS rn
    FROM pgb_session.history
)
UPDATE pgb_session.history h
SET n = renum.rn
FROM renum
WHERE h.ctid = renum.ctid;

ALTER TABLE pgb_session.history
    ALTER COLUMN n SET NOT NULL;

ALTER TABLE pgb_session.history
    ADD PRIMARY KEY (session_id, n);

-- 3. snapshot: same treatment, and ensure (session_id, n) is the primary key
--    (older installs keyed on (session_id, ts)).
ALTER TABLE pgb_session.snapshot
    ALTER COLUMN n DROP IDENTITY IF EXISTS;

ALTER TABLE pgb_session.snapshot
    DROP CONSTRAINT IF EXISTS snapshot_pkey;

WITH renum AS (
    SELECT ctid, row_number() OVER (PARTITION BY session_id ORDER BY ts, n) AS rn
    FROM pgb_session.snapshot
)
UPDATE pgb_session.snapshot s
SET n = renum.rn
FROM renum
WHERE s.ctid = renum.ctid;

ALTER TABLE pgb_session.snapshot
    ALTER COLUMN n SET NOT NULL;

ALTER TABLE pgb_session.snapshot
    ADD PRIMARY KEY (session_id, n);

-- 4. Re-apply the function definitions whose bodies depend on the new scheme:
--    open() now records history before its snapshot, and replay() prunes history
--    by sequence. (navigate(), reload(), and close() are unchanged.)
\ir 60_pgb_session_open.sql
\ir 60_pgb_session_replay.sql
