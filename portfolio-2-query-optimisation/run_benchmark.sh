#!/usr/bin/env bash
# Measures every query WITHOUT optimisation structures (before) and WITH them (after).
# Output:  results/plans_before.txt, results/plans_after.txt, results/summary.md
# Connection: standard PG* variables (PGDATABASE=access_pensions ...)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RES="$HERE/results"; mkdir -p "$RES"
q() { psql -X -tAc "$1"; }

CID=$(q "SELECT customer_id FROM ap.customer WHERE status='ACTIVE' ORDER BY customer_id OFFSET 777 LIMIT 1")
PHONE=$(q "SELECT phone_number FROM ap.customer WHERE customer_id = 1234")
EMP=$(q "SELECT employer_id FROM ap.employer ORDER BY employer_id OFFSET 4 LIMIT 1")
echo "Test parameters: customer_id=$CID phone=$PHONE employer_id=$EMP"

run_query() {   # $1 = file  $2 = extra flag for EXPLAIN options
  { echo "EXPLAIN (ANALYZE, BUFFERS)"; cat "$1"; } | psql -X -q -v cid="$CID" -v phone="'$PHONE'" -v emp="$EMP"
}

phase() {
  local ph="$1" out="$RES/plans_$1.txt"; : > "$out"; : > "$RES/times_$ph.csv"
  for f in "$HERE"/queries/q*.sql; do
    local name; name=$(basename "$f" .sql)
    if [ "$ph" = before ] && [[ "$name" == *_mv ]]; then continue; fi
    run_query "$f" > /dev/null                         # warm-up run (populate cache)
    local plan; plan=$(run_query "$f")                 # measured run
    { echo "===== $name ($ph) ====="; cat "$f"; echo; echo "$plan"; echo; } >> "$out"
    local ms; ms=$(echo "$plan" | awk '/Execution Time/ {print $3}')
    echo "$name,$ms" >> "$RES/times_$ph.csv"
    printf "  %-45s %10s ms\n" "$name" "$ms"
  done
}

echo "== BEFORE (no optimisation indexes / materialised view) =="
psql -X -q -v ON_ERROR_STOP=1 -f "$HERE/sql/02_drop_indexes.sql"
phase before
echo "== AFTER (indexes + materialised view) =="
psql -X -q -v ON_ERROR_STOP=1 -f "$HERE/sql/01_create_indexes.sql"
phase after

python3 - "$RES" <<'PY'
import csv, sys
res = sys.argv[1]
before = dict(csv.reader(open(f"{res}/times_before.csv")))
after  = dict(csv.reader(open(f"{res}/times_after.csv")))
lines = ["| Query | Before (ms) | After (ms) | Speed-up |", "|---|---:|---:|---:|"]
for name, a in after.items():
    b = before.get(name)
    if b is None:
        base = name.replace("_mv", "")
        b = before.get(base); label = name + " (vs base query)"
    else:
        label = name
    sp = f"{float(b)/float(a):.1f}x" if b and float(a) > 0 else "n/a"
    lines.append(f"| {label} | {b} | {a} | {sp} |")
open(f"{res}/summary.md", "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
PY
echo "Plans saved in $RES"
