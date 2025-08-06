#!/usr/bin/env bash
set -euo pipefail

# Run regression tests using pg_regress. Requires a running PostgreSQL server
# accessible via settings provided via PGHOST/PGUSER environment variables.

if ! command -v pg_config >/dev/null; then
  echo "pg_config not found. Install PostgreSQL development packages to run tests." >&2
  exit 1
fi

PG_REGRESS="${PG_REGRESS:-$(pg_config --bindir)/pg_regress}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/results"
mkdir -p "$OUTPUT_DIR"

export PGUSER="${PGUSER:-postgres}"
export PGHOST="${PGHOST:-localhost}"

cd "$SCRIPT_DIR/sql"
"$PG_REGRESS" --inputdir="$SCRIPT_DIR" --outputdir="$OUTPUT_DIR" --expecteddir="$SCRIPT_DIR/expected" \
  session reload_invalid reload_concurrent replay replay_missing_snapshot
