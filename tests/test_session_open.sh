#!/usr/bin/env bash
set -euo pipefail

DB=pg_browser_test

sudo -u postgres dropdb --if-exists "$DB"
sudo -u postgres createdb "$DB"

sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f sql/00_install.sql
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f sql/60_pgb_session.sql

SESSION_ID=$(sudo -u postgres psql -d "$DB" -t -A -c "SELECT pgb_session.open('pgb://local/demo');")

if [[ ! "$SESSION_ID" =~ ^[0-9a-f-]{36}$ ]]; then
  echo "open() returned invalid uuid: $SESSION_ID"
  exit 1
fi

URL=$(sudo -u postgres psql -d "$DB" -t -A -c "SELECT current_url FROM pgb_session.session WHERE id = '$SESSION_ID';")
if [[ "$URL" != "pgb://local/demo" ]]; then
  echo "unexpected current_url: $URL"
  exit 1
fi

COUNT=$(sudo -u postgres psql -d "$DB" -t -A -c "SELECT count(*) FROM pgb_session.history WHERE session_id = '$SESSION_ID' AND n = 1 AND url = 'pgb://local/demo';")
if [[ "$COUNT" -ne 1 ]]; then
  echo "history row missing"
  exit 1
fi

# Close the session
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -c "SELECT pgb_session.close('$SESSION_ID');" >/dev/null

COUNT=$(sudo -u postgres psql -d "$DB" -t -A -c "SELECT count(*) FROM pgb_session.session WHERE id = '$SESSION_ID';")
if [[ "$COUNT" -ne 0 ]]; then
  echo "session row not deleted"
  exit 1
fi

COUNT=$(sudo -u postgres psql -d "$DB" -t -A -c "SELECT count(*) FROM pgb_session.history WHERE session_id = '$SESSION_ID';")
if [[ "$COUNT" -ne 0 ]]; then
  echo "history rows not deleted"
  exit 1
fi

echo "session_open integration test passed"
