#!/usr/bin/env bash
# Demo 6 | Write skew: rule "only one open 25% application per customer" checked by application code.
# REPEATABLE READ lets both inserts succeed (rule broken); SERIALIZABLE aborts one with SQLSTATE 40001.
set -uo pipefail; source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"; reset_demo
for LEVEL in "REPEATABLE READ" "SERIALIZABLE"; do
  psql -X -q -c "TRUNCATE ap_demo.application RESTART IDENTITY"
  echo "=== $LEVEL ==="
  for S in S1 S2; do
    $S <<SQL &
BEGIN ISOLATION LEVEL $LEVEL;
SELECT '$S rule check: open applications for customer 7 =' AS step, count(*) FROM ap_demo.application WHERE customer_id = 7 AND status = 'OPEN';
SELECT pg_sleep(2);
INSERT INTO ap_demo.application (customer_id, status) VALUES (7, 'OPEN');
COMMIT;
SQL
  done
  wait
  psql -X -q -c "SELECT 'RESULT: open applications for customer 7' AS note, count(*) FROM ap_demo.application WHERE customer_id = 7 AND status='OPEN'" | sed 's/^/[RESULT] /'
  echo
done
