# Portfolio 2 – Query Processing and Optimisation

## Run
```bash
export PGDATABASE=access_pensions      # plus PGHOST / PGUSER / PGPASSWORD if needed
./portfolio-2-query-optimisation/run_benchmark.sh
```
The script (1) drops every optimisation structure, (2) runs each query in `queries/` with `EXPLAIN (ANALYZE, BUFFERS)` after a warm-up run, (3) creates the indexes and materialised view from `sql/01_create_indexes.sql`, (4) repeats, and writes:
`results/plans_before.txt`, `results/plans_after.txt`, `results/summary.md` (use these for screenshots and the performance table).

## Queries and the structure that targets each
| Query | Business question | Optimisation |
|---|---|---|
| Q1 | 12-month statement for one customer | composite covering index `(customer_id, txn_date DESC, txn_id DESC) INCLUDE (...)` |
| Q2 | Remittance schedule for one employer | partial index `(employer_id, txn_date) WHERE txn_type='CONTRIBUTION'` |
| Q3 | Company-wide monthly contributions | materialised view `mv_monthly_contributions` (an index cannot help a full-ledger aggregate) |
| Q4 | Lookup by phone | B-tree on `phone_number` |
| Q5 | Partial surname search | `pg_trgm` GIN index |
| Q6 | Pending-benefit work queue | partial index on `application_date WHERE status='PENDING'` |
| Q7 | Top balances per fund (window function) | composite index; **little change expected** – included to show that not every query benefits |

## Analysis guidance
Read each plan top-down: scan type (Seq Scan → Index / Index Only / Bitmap Scan), estimated vs actual rows, buffers read, execution time. Trade-offs to discuss: write overhead of extra indexes on the append-heavy ledger, storage cost, materialised-view staleness (refresh schedule), and why Q3 (base query) and Q7 do not improve.
Scale the data with `SEED_CUSTOMERS=100000 ./scripts/setup_local.sh` to see larger gaps.
