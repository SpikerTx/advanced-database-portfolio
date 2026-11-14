# Evidence checklist (capture your OWN screenshots after running each step)

| # | Portfolio | Command | Screenshot / file to keep |
|---|---|---|---|
| 1 | 1 | `./scripts/setup_local.sh` | Final row counts + "violations = 0" table |
| 2 | 1 | `psql -c "\d+ ap.customer"` and `\d+ ap.account_transaction` | Keys and constraints |
| 3 | 1 | open `er-diagram/access_pensions_er.png` | ER diagram |
| 4 | 2 | `./portfolio-2-query-optimisation/run_benchmark.sh` | Summary table + one plan before/after (Seq Scan → Index Scan) |
| 5 | 3 | `./portfolio-3-transactions-concurrency/run_all_demos.sh` | Each demo's output (lost update, deadlock, serialization failure) |
| 6 | 4 | `docker compose exec mongo mongosh access_pensions --file /scripts/queries.js` | Mongo query/aggregation output |
| 7 | 4 | `psql -f portfolio-4-nosql/postgres-jsonb/02_jsonb_queries.sql` | JSONB document + GIN plan |
| 8 | 5 | `docker compose up -d primary replica` then `verify_replication.sh` | `pg_stat_replication`, replica read-only error |
| 9 | 5 | `psql -f portfolio-5-distributed-cloud/sql/01_partitioning_and_sharding.sql` | Partition pruning plan |
| 10 | all | GitHub → Actions tab | Green `build-and-verify` run |
