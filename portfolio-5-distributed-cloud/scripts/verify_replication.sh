#!/usr/bin/env bash
# Verifies PostgreSQL streaming replication and (optionally) demonstrates manual failover.
# Defaults match docker-compose.yml: primary on localhost:5432, replica on localhost:5433.
#   ./verify_replication.sh              # checks + replication-lag demonstration
#   ./verify_replication.sh --failover   # additionally promotes the replica (destructive for the demo pair)
set -uo pipefail
HOST="${PGHOST:-localhost}"; PPORT="${PRIMARY_PORT:-5432}"; RPORT="${REPLICA_PORT:-5433}"
DB="${PGDATABASE:-access_pensions}"; USER_="${PGUSER:-postgres}"
P() { psql -X -q -h "$HOST" -p "$PPORT" -U "$USER_" -d "$DB" -P pager=off "$@"; }
R() { psql -X -q -h "$HOST" -p "$RPORT" -U "$USER_" -d "$DB" -P pager=off "$@"; }

echo "### 1. Primary: connected standbys (pg_stat_replication)"
P -c "SELECT application_name, state, sync_state, pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replay_lag_bytes FROM pg_stat_replication;"

echo "### 2. Role check: primary should be 'f', replica should be 't' (pg_is_in_recovery)"
echo -n "primary: "; P -tAc "SELECT pg_is_in_recovery();"
echo -n "replica: "; R -tAc "SELECT pg_is_in_recovery();"

echo "### 3. Write on PRIMARY, read the same row on REPLICA (read-your-writes after replication)"
CID=$(P -tAc "SELECT customer_id FROM ap.customer WHERE status='ACTIVE' ORDER BY customer_id OFFSET 100 LIMIT 1")
REF="REPL-$(date +%s)"
P -c "INSERT INTO ap.account_transaction (customer_id, txn_type, contribution_source, amount, reference) VALUES ($CID,'CONTRIBUTION','VOLUNTARY',1000,'$REF');"
sleep 1
echo "primary sees:"; P -c "SELECT reference, amount, balance_after FROM ap.account_transaction WHERE reference='$REF';"
echo "replica sees:"; R -c "SELECT reference, amount, balance_after FROM ap.account_transaction WHERE reference='$REF';"

echo "### 4. Write on REPLICA must fail (read-only standby)"
R -c "INSERT INTO ap.account_transaction (customer_id, txn_type, contribution_source, amount, reference) VALUES ($CID,'CONTRIBUTION','VOLUNTARY',1,'SHOULD-FAIL');" 2>&1 | head -3

echo "### 5. Replication delay observed on the replica"
R -c "SELECT now() - pg_last_xact_replay_timestamp() AS replay_delay, pg_last_wal_receive_lsn() AS received, pg_last_wal_replay_lsn() AS replayed;"

if [ "${1:-}" = "--failover" ]; then
  echo "### 6. FAILOVER: promote the replica to primary"
  R -c "SELECT pg_promote(wait => true);"
  echo -n "replica is now in recovery? "; R -tAc "SELECT pg_is_in_recovery();"
  R -c "INSERT INTO ap.account_transaction (customer_id, txn_type, contribution_source, amount, reference) VALUES ($CID,'CONTRIBUTION','VOLUNTARY',2000,'POST-FAILOVER-$(date +%s)');"
  echo "Write accepted by the promoted node. Rebuild the old primary as a new replica before reuse."
fi
