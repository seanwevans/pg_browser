#!/usr/bin/env bash
set -euo pipefail

# Run the pg_browser golden suite with pg_regress against a running PostgreSQL
# server. Connection parameters come from the standard libpq environment
# variables (PGHOST/PGPORT/PGUSER/PGPASSWORD); sensible defaults are applied
# below. The server must be reachable over a local Unix socket as well, because
# the concurrent tests use dblink to open additional connections back to it.

if ! command -v pg_config >/dev/null; then
  echo "pg_config not found. Install the PostgreSQL development package" \
       "(e.g. postgresql-server-dev-16) to run the regression suite." >&2
  exit 1
fi

# pg_regress is not installed in bindir; it lives under the PGXS test tree.
find_pg_regress() {
  if [ -n "${PG_REGRESS:-}" ] && [ -x "${PG_REGRESS}" ]; then
    echo "${PG_REGRESS}"
    return 0
  fi
  local candidate
  for candidate in \
    "$(pg_config --bindir)/pg_regress" \
    "$(pg_config --pkglibdir)/pgxs/src/test/regress/pg_regress" \
    "$(pg_config --libdir)/postgresql/pgxs/src/test/regress/pg_regress"; do
    if [ -x "${candidate}" ]; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

if ! PG_REGRESS="$(find_pg_regress)"; then
  echo "pg_regress not found near $(pg_config --bindir)." \
       "Install the PostgreSQL development package to run the suite." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PGUSER="${PGUSER:-postgres}"
export PGHOST="${PGHOST:-localhost}"

# Run from tests/sql so each test's `\ir ../../sql/*.sql` includes resolve
# (pg_regress feeds scripts to psql on stdin, so includes are relative to CWD).
cd "${SCRIPT_DIR}/sql"
exec "${PG_REGRESS}" \
  --inputdir="${SCRIPT_DIR}" \
  --outputdir="${SCRIPT_DIR}" \
  --expecteddir="${SCRIPT_DIR}" \
  --bindir="$(pg_config --bindir)" \
  --schedule="${SCRIPT_DIR}/regress_schedule"
