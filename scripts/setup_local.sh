#!/usr/bin/env bash
# Creates the database (if missing) on a local/remote PostgreSQL 14+ server and builds everything.
# Usage:  ./scripts/setup_local.sh            (uses your normal PG* environment variables)
#         DB_NAME=mydb SEED_CUSTOMERS=5000 ./scripts/setup_local.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_NAME="${DB_NAME:-access_pensions}"

if ! psql -X -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1; then
  echo ">> creating database ${DB_NAME}"
  createdb "${DB_NAME}"
fi
export PGDATABASE="${DB_NAME}"
"${ROOT}/scripts/build_database.sh"
