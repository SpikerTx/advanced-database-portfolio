#!/usr/bin/env bash
# Demo 3 | Lost update (naive read-modify-write) vs pessimistic locking (SELECT ... FOR UPDATE)
set -uo pipefail; source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"; reset_demo
echo "=== NAIVE: both sessions read 1,000,000 then write back 'value read + deposit' ==="
psql -X -q -c "UPDATE ap_demo.account SET balance = 1000000 WHERE id = 1"
S1 <<'SQL' &
BEGIN;
SELECT 'S1 read' AS step, balance FROM ap_demo.account WHERE id = 1;
SELECT pg_sleep(2);
UPDATE ap_demo.account SET balance = 1000000 + 100000 WHERE id = 1;   -- value computed from the stale read
COMMIT;
SQL
sleep 1
S2 <<'SQL'
BEGIN;
SELECT 'S2 read' AS step, balance FROM ap_demo.account WHERE id = 1;
UPDATE ap_demo.account SET balance = 1000000 + 200000 WHERE id = 1;
COMMIT;
SQL
wait
psql -X -q -c "SELECT 'RESULT (expected 1,300,000)' AS note, balance FROM ap_demo.account WHERE id = 1" | sed 's/^/[RESULT] /'

echo; echo "=== SAFE: SELECT ... FOR UPDATE serialises the two deposits ==="
psql -X -q -c "UPDATE ap_demo.account SET balance = 1000000 WHERE id = 1"
S1 <<'SQL' &
BEGIN;
SELECT 'S1 locked row' AS step, balance FROM ap_demo.account WHERE id = 1 FOR UPDATE;
SELECT pg_sleep(2);
UPDATE ap_demo.account SET balance = balance + 100000 WHERE id = 1;
COMMIT;
SQL
sleep 1
S2 <<'SQL'
BEGIN;
SELECT 'S2 waiting for lock...' AS step;
SELECT 'S2 got lock, sees' AS step, balance FROM ap_demo.account WHERE id = 1 FOR UPDATE;
UPDATE ap_demo.account SET balance = balance + 200000 WHERE id = 1;
COMMIT;
SQL
wait
psql -X -q -c "SELECT 'RESULT (expected 1,300,000)' AS note, balance FROM ap_demo.account WHERE id = 1" | sed 's/^/[RESULT] /'
