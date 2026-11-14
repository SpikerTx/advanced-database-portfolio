# Advanced Database Systems Portfolio – Access Pensions Limited

**Course:** MIT 8103 Advanced Database Systems (MIVA Open University, 2026/2027, 40 marks)
**Case study:** Access Pensions Limited – a simulated pension fund administrator (customer biodata, contribution/payment ledger, benefit applications). **All data is synthetic.**

## Quick start
### Option A – Docker (PostgreSQL primary + replica + MongoDB)
```bash
docker compose up -d primary replica mongo
docker compose logs -f primary          # wait for "database system is ready to accept connections"
psql -h localhost -U postgres -d access_pensions      # password: ap_password (see .env.example)
```
### Option B – Local PostgreSQL 14+ (no Docker)
```bash
export PGHOST=localhost PGUSER=postgres PGPASSWORD=<your password>
./scripts/setup_local.sh                 # creates database access_pensions and builds everything (~15–60 s)
SEED_CUSTOMERS=50000 ./scripts/setup_local.sh   # larger dataset
```
On Windows use **Git Bash** or WSL to run the `.sh` scripts.
The build is repeatable: it drops and recreates schema `ap`.

## What the build creates
Schema `ap` with 8 tables, triggers, workflow functions, ~20,000 synthetic customers, ~560,000 ledger rows, indexes, materialised view, JSONB documents, roles. `scripts/verify_build.sql` prints row counts and integrity checks (all must be 0).

## Repository map
| Folder | Marks | Content |
|---|---|---|
| `portfolio-1-database-design/` | 7 | ER diagram, schema, constraints, triggers, normalisation |
| `portfolio-2-query-optimisation/` | 7 | Queries, `EXPLAIN ANALYZE` before/after, indexes, materialised view |
| `portfolio-3-transactions-concurrency/` | 7 | Commit/rollback, isolation levels, locking, deadlock, serializable |
| `portfolio-4-nosql/` | 7 | MongoDB document model + PostgreSQL JSONB |
| `portfolio-5-distributed-cloud/` | 6 | Replication, failover, partitioning/sharding, cloud design |
| `docs/` | 6 | Portfolio summary, evidence checklist, commit guide |
| `.github/workflows/ci.yml` | – | Builds and tests everything on each push (automatic evidence) |

## Tested with
PostgreSQL 16 (build, benchmark, all six concurrency demos, partitioning, streaming replication, synchronous mode and failover). The MongoDB scripts and the Docker Compose files were checked for syntax and data logic but **not executed against live containers in the authoring environment** – run them once and keep the output as evidence.

## Sources and tools
PostgreSQL 16 documentation; MongoDB 7 documentation; Docker; Graphviz; Mermaid. AI assistance is declared in `docs/AI_USE_DECLARATION.md`.
