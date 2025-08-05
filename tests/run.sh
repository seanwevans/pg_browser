#!/usr/bin/env bash
# Usage: PGUSER=<user> PGHOST=<host> PGDATABASE=<database> tests/run.sh
# Runs pg_browser tests using the provided connection parameters.
set -euo pipefail
psql -v ON_ERROR_STOP=1 -h "${PGHOST}" -U "${PGUSER}" -d "${PGDATABASE}" -f "$(dirname "$0")/test_pgb_session.sql"
