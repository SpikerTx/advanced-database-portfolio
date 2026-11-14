#!/usr/bin/env bash
# Demo 4 | Real schema: two simultaneous payments against one RSA - the ledger trigger's row lock serialises them,
# so the second payment sees the reduced balance and is rejected (no overdraft, no lost update).
set -uo pipefail; source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
export PGOPTIONS='--search_path=ap,public'
CID=$(psql -X -tAc "SELECT customer_id FROM ap.customer WHERE status='ACTIVE' AND current_balance > 500000 ORDER BY customer_id OFFSET 10 LIMIT 1")
BAL=$(psql -X -tAc "SELECT current_balance FROM ap.customer WHERE customer_id=$CID")
echo "Customer $CID has balance $BAL"
# two APPROVED voluntary withdrawals, each for 60% of the balance (together they exceed the balance)
AMT=$(psql -X -tAc "SELECT round(current_balance * 0.6, 2) FROM ap.customer WHERE customer_id=$CID")
B1=$(psql -X -tAc "SELECT ap.submit_benefit_application($CID,'VOLUNTARY_WITHDRAWAL',$AMT,'CONC-1')")
B2=$(psql -X -tAc "SELECT ap.submit_benefit_application($CID,'VOLUNTARY_WITHDRAWAL',$AMT,'CONC-2')")
psql -X -q -c "SELECT ap.approve_benefit($B1,'demo.officer'); SELECT ap.approve_benefit($B2,'demo.officer');" > /dev/null
echo "Benefit $B1 and $B2 approved for $AMT each. Now paying both concurrently..."
S1 <<SQL &
BEGIN;
SELECT 'S1 paying benefit $B1' AS step, ap.pay_benefit($B1) AS txn_id;
SELECT pg_sleep(3);          -- hold the lock for 3 seconds before committing
COMMIT;
SQL
sleep 1
S2 <<SQL
\timing on
SELECT 'S2 paying benefit $B2 (will wait for S1)' AS step;
SELECT ap.pay_benefit($B2);
SQL
wait
psql -X -q -c "SELECT benefit_id, status FROM ap.benefit_application WHERE benefit_id IN ($B1,$B2) ORDER BY 1" | sed 's/^/[RESULT] /'
psql -X -q -c "SELECT current_balance FROM ap.customer WHERE customer_id=$CID" | sed 's/^/[RESULT] /'
