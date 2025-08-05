#!/usr/bin/env bash
# Usage: PGUSER=<user> PGHOST=<host> PGDATABASE=<database> tests/run.sh
# Runs pg_browser tests using the provided connection parameters.
set -euo pipefail

# Use default connection parameters when not provided to avoid unbound
# variable errors. These mirror the defaults used by run_regress.sh.
export PGUSER="${PGUSER:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export PGDATABASE="${PGDATABASE:-postgres}"

psql -v ON_ERROR_STOP=1 -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -f "$(dirname "$0")/test_pgb_session.sql"
