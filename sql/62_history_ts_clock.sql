ALTER TABLE pgb_session.history
    ALTER COLUMN ts SET DEFAULT clock_timestamp();

