#!/usr/bin/env bash
# Switches the primary to SYNCHRONOUS replication (consistency over latency) and back.
#   ./enable_sync_replication.sh on     commits wait until the standby has replayed them (remote_apply)
#   ./enable_sync_replication.sh off    back to asynchronous (lower latency; small data-loss window on failover)
set -euo pipefail
HOST="${PGHOST:-localhost}"; PPORT="${PRIMARY_PORT:-5432}"; DB="${PGDATABASE:-access_pensions}"; U="${PGUSER:-postgres}"
Q() { psql -X -q -h "$HOST" -p "$PPORT" -U "$U" -d "$DB" -tAc "$1"; }
if [ "${1:-}" = "on" ]; then
  Q "ALTER SYSTEM SET synchronous_standby_names = 'FIRST 1 (replica1)'"
  Q "ALTER SYSTEM SET synchronous_commit = 'remote_apply'"
else
  Q "ALTER SYSTEM RESET synchronous_standby_names"
  Q "ALTER SYSTEM RESET synchronous_commit"
fi
Q "SELECT pg_reload_conf()" >/dev/null
sleep 1
psql -X -h "$HOST" -p "$PPORT" -U "$U" -d "$DB" -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
