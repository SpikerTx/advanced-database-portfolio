#!/usr/bin/env bash
# Demo 5 | Deadlock: two sessions lock the same two rows in opposite order; PostgreSQL aborts one victim.
set -uo pipefail; source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"; reset_demo
S1 <<'SQL' &
BEGIN;
UPDATE ap_demo.account SET balance = balance - 1000 WHERE id = 1;
SELECT 'S1 holds row 1' AS step;
SELECT pg_sleep(2);
UPDATE ap_demo.account SET balance = balance + 1000 WHERE id = 2;
COMMIT;
SQL
sleep 0.5
S2 <<'SQL'
BEGIN;
UPDATE ap_demo.account SET balance = balance - 500 WHERE id = 2;
SELECT 'S2 holds row 2' AS step;
SELECT pg_sleep(2);
UPDATE ap_demo.account SET balance = balance + 500 WHERE id = 1;
COMMIT;
SQL
wait
echo "Mitigation: always lock rows in a consistent order (e.g. ORDER BY id) - see README."
