#!/usr/bin/env bash
set -euo pipefail

# Apply every pg_browser SQL file in sequence against a throwaway database to
# verify that a fresh install plus the full migration chain runs without errors
# and converges, then smoke-test the resulting schema. Connection parameters come
# from the standard libpq environment variables.
#
# Usage: PGHOST=... PGUSER=... tests/run_migrations.sh [database]

export PGUSER="${PGUSER:-postgres}"
export PGHOST="${PGHOST:-localhost}"

DB="${1:-pgb_migrate}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Top-level files in application order. The sub-files (60_pgb_session_*.sql) are
# pulled in via \ir and are not listed here.
FILES=(
  00_install.sql
  60_pgb_session.sql
  61_add_session_current_url_check.sql
  61_pgb_session_history_bigint.sql
  62_history_ts_clock.sql
  63_session_snapshot_clock.sql
  64_session_snapshot_focus.sql
  64_session_snapshot_identity.sql
  65_session_per_session_n.sql
)

psql -d postgres -v ON_ERROR_STOP=1 -q \
  -c "DROP DATABASE IF EXISTS ${DB}" \
  -c "CREATE DATABASE ${DB}"

for f in "${FILES[@]}"; do
  echo "applying sql/${f}"
  psql -d "${DB}" -v ON_ERROR_STOP=1 -q -f "${REPO}/sql/${f}"
done

echo "smoke-testing upgraded schema"
psql -d "${DB}" -v ON_ERROR_STOP=1 -q <<'SQL'
SELECT pgb_session.open('pgb://local/ci') AS sid \gset
SELECT pgb_session.navigate(:'sid', 'http://example.com/ci');
SELECT pgb_session.reload(:'sid');
DO $$
DECLARE
    v_ns BIGINT[];
BEGIN
    SELECT array_agg(n ORDER BY n) INTO v_ns
    FROM pgb_session.history
    WHERE session_id = (SELECT id FROM pgb_session.session LIMIT 1);
    IF v_ns IS DISTINCT FROM ARRAY[1, 2, 3]::BIGINT[] THEN
        RAISE EXCEPTION 'expected per-session history n {1,2,3}, got %', v_ns;
    END IF;
END $$;
SQL

echo "migration-order check passed"
