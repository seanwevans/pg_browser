#!/usr/bin/env bash
set -euo pipefail
sudo -u postgres psql -v ON_ERROR_STOP=1 -f "$(dirname "$0")/test_pgb_session.sql" -d postgres
