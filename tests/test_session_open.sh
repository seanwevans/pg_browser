#!/usr/bin/env bash
# Usage: PGUSER=<user> PGHOST=<host> PGPORT=<port> [PGDATABASE=<db>] tests/test_session_open.sh
# Requires a PostgreSQL server accessible via the provided connection parameters.
# The specified user must have privileges to create and drop databases.
set -euo pipefail

DB=pg_browser_test

# Provide defaults to avoid unbound variable errors
export PGUSER="${PGUSER:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGDATABASE="${PGDATABASE:-postgres}"

dropdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" --if-exists "$DB"
createdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$DB"

psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB" -v ON_ERROR_STOP=1 -f sql/00_install.sql
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB" -v ON_ERROR_STOP=1 -f sql/60_pgb_session.sql

SESSION_ID=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB" -t -A -c "SELECT pgb_session.open('pgb://local/demo');")

if [[ ! "$SESSION_ID" =~ ^[0-9a-f-]{36}$ ]]; then
  echo "open() returned invalid uuid: $SESSION_ID"
  exit 1
fi

URL=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB" -t -A -c "SELECT current_url FROM pgb_session.session WHERE id = '$SESSION_ID';")
if [[ "$URL" != "pgb://local/demo" ]]; then
  echo "unexpected current_url: $URL"
  exit 1
fi

COUNT=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB" -t -A -c "SELECT count(*) FROM pgb_session.history WHERE session_id = '$SESSION_ID' AND url = 'pgb://local/demo';")
if [[ "$COUNT" -ne 1 ]]; then
  echo "history row missing"
  exit 1
fi

# Close the session
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB" -v ON_ERROR_STOP=1 -c "SELECT pgb_session.close('$SESSION_ID');" >/dev/null

COUNT=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB" -t -A -c "SELECT count(*) FROM pgb_session.session WHERE id = '$SESSION_ID';")
if [[ "$COUNT" -ne 0 ]]; then
  echo "session row not deleted"
  exit 1
fi

COUNT=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB" -t -A -c "SELECT count(*) FROM pgb_session.history WHERE session_id = '$SESSION_ID';")
if [[ "$COUNT" -ne 0 ]]; then
  echo "history rows not deleted"
  exit 1
fi

echo "session_open integration test passed"
