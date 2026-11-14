# Shared helper for the two-session demonstrations.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RES="$HERE/results"; mkdir -p "$RES"
S1() { psql -X -q -v ON_ERROR_STOP=0 -P pager=off -P footer=off "$@" 2>&1 | sed 's/^/[S1] /'; }
S2() { psql -X -q -v ON_ERROR_STOP=0 -P pager=off -P footer=off "$@" 2>&1 | sed 's/^/[S2] /'; }
reset_demo() { psql -X -q -v ON_ERROR_STOP=1 -f "$HERE/sql/00_demo_setup.sql"; }
