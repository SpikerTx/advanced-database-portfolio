#!/usr/bin/env bash
# Runs every demonstration and stores the console output in results/ (use these logs as screenshot evidence).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; mkdir -p "$HERE/results"
psql -X -q -v ON_ERROR_STOP=0 -f "$HERE/sql/01_commit_rollback.sql" 2>&1 | tee "$HERE/results/01_commit_rollback.log"
for s in 02_isolation_levels 03_lost_update_and_locking 04_concurrent_withdrawals 05_deadlock 06_write_skew_serializable; do
  echo; echo "################ $s ################"
  bash "$HERE/$s.sh" 2>&1 | tee "$HERE/results/$s.log"
done
