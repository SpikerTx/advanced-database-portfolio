#!/usr/bin/env bash
# Builds the complete Access Pensions database (schema, logic, seed data, indexes, views, JSONB documents).
# Connection settings come from the standard libpq variables: PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE
# Optional: SEED_CUSTOMERS (default 20000) controls the size of the synthetic dataset.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED_CUSTOMERS="${SEED_CUSTOMERS:-20000}"

run() {
  echo ">> $1"
  psql -X -q -v ON_ERROR_STOP=1 -v customers="$SEED_CUSTOMERS" -f "$ROOT/$1"
}

run portfolio-1-database-design/sql/01_schema.sql
run portfolio-1-database-design/sql/02_functions_triggers.sql
run portfolio-1-database-design/sql/03_seed_data.sql
run portfolio-1-database-design/sql/04_views_security.sql
run portfolio-2-query-optimisation/sql/01_create_indexes.sql
run portfolio-4-nosql/postgres-jsonb/01_jsonb_documents.sql

echo ">> verification"
psql -X -v ON_ERROR_STOP=1 -f "$ROOT/scripts/verify_build.sql"
echo "Build complete."
