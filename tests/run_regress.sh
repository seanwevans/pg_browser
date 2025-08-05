#!/usr/bin/env bash
set -euo pipefail

# Run regression tests using pg_regress. Requires a running PostgreSQL server
# accessible via local Unix socket and the `postgres` superuser.

if ! command -v pg_config >/dev/null; then
  echo "pg_config not found. Install PostgreSQL development packages to run tests." >&2
  exit 1
fi

PG_REGRESS="$(pg_config --bindir)/pg_regress"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/results"
mkdir -p "$OUTPUT_DIR"
chown postgres:postgres "$OUTPUT_DIR"

su postgres -c "cd $SCRIPT_DIR/sql && /usr/lib/postgresql/16/lib/pgxs/src/test/regress/pg_regress --inputdir=$SCRIPT_DIR --outputdir=$OUTPUT_DIR --expecteddir=$SCRIPT_DIR/expected session reload_invalid reload_concurrent"
