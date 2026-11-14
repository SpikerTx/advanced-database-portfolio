#!/usr/bin/env bash
# Starts a hot-standby replica: clones the primary with pg_basebackup on first start, then streams WAL.
set -euo pipefail
export PGPASSWORD="${REPLICATION_PASSWORD:-repl_password}"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"

until pg_isready -h primary -p 5432 -U replicator >/dev/null 2>&1; do
  echo "waiting for primary..."; sleep 2
done

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "cloning primary with pg_basebackup..."
  find "$PGDATA" -mindepth 1 -delete 2>/dev/null || true
  pg_basebackup -h primary -p 5432 -U replicator -D "$PGDATA" -X stream -R -P --checkpoint=fast
fi
chmod 700 "$PGDATA"

# application_name lets the primary identify this standby (needed for synchronous replication)
exec postgres -c hot_standby=on \
  -c primary_conninfo="host=primary port=5432 user=replicator password=${PGPASSWORD} application_name=replica1"
