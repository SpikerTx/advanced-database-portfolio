# Portfolio 3 – Transactions and Concurrency

```bash
export PGDATABASE=access_pensions
./portfolio-3-transactions-concurrency/run_all_demos.sh      # ~30 s; logs saved in results/
```
> The demos post a few rows to the live ledger. Re-run `./scripts/setup_local.sh` to reset to the pristine seed data.

| # | Script | Demonstrates | Expected outcome |
|---|---|---|---|
| 1 | `sql/01_commit_rollback.sql` | COMMIT, ROLLBACK, SAVEPOINT, atomic submit→approve→pay, failed overdraft | Balance only changes for committed work |
| 2 | `02_isolation_levels.sh` | Non-repeatable read | READ COMMITTED: second read changes; REPEATABLE READ: stable snapshot |
| 3 | `03_lost_update_and_locking.sh` | Lost update, fixed with `SELECT … FOR UPDATE` | Naive result 1,100,000 (wrong); locked result 1,300,000 |
| 4 | `04_concurrent_withdrawals.sh` | Two simultaneous payments on one RSA | Second payment waits ~2 s for the row lock, then is rejected: *Insufficient balance* |
| 5 | `05_deadlock.sh` | Opposite lock order | PostgreSQL aborts one session: `deadlock detected` |
| 6 | `06_write_skew_serializable.sh` | Write skew | REPEATABLE READ: rule violated (2 rows); SERIALIZABLE: one transaction aborted (SQLSTATE 40001) |

## Control mechanisms used in the schema
* Row lock on the customer inside `fn_post_transaction()` serialises postings per customer (concurrent customers do not block each other).
* `CHECK` constraints and triggers make overdrafts impossible; the ledger is append-only.
* Consistent lock order (benefit row, then customer row) in `approve_benefit` / `pay_benefit` avoids deadlocks.
* Applications should retry on SQLSTATE `40001` (serialization failure) and `40P01` (deadlock).
