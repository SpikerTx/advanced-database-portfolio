#!/usr/bin/env bash
# Demo 2 | Isolation levels: non-repeatable read (READ COMMITTED) vs stable snapshot (REPEATABLE READ)
set -uo pipefail; source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"; reset_demo
for LEVEL in "READ COMMITTED" "REPEATABLE READ"; do
  psql -X -q -c "UPDATE ap_demo.account SET balance = 1000000 WHERE id = 1"
  echo "=== Isolation level: $LEVEL ==="
  S1 <<SQL &
BEGIN ISOLATION LEVEL $LEVEL;
SELECT 'S1 first read ' AS step, balance FROM ap_demo.account WHERE id = 1;
SELECT pg_sleep(2);
SELECT 'S1 second read' AS step, balance FROM ap_demo.account WHERE id = 1;
COMMIT;
SQL
  sleep 1
  S2 -c "UPDATE ap_demo.account SET balance = balance + 250000 WHERE id = 1; SELECT 'S2 committed +250,000' AS step;"
  wait
  echo
done
