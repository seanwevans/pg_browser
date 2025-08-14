ALTER TABLE pgb_session.session
    ALTER COLUMN created_at SET DEFAULT clock_timestamp();

ALTER TABLE pgb_session.snapshot
    ALTER COLUMN ts SET DEFAULT clock_timestamp();
