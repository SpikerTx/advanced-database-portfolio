# Portfolio 5 – Distributed and Cloud Database Exercise

| Topic | Implementation | Evidence |
|---|---|---|
| **Replication** (availability) | PostgreSQL streaming replication: primary + hot-standby replica (`docker-compose.yml`) | `scripts/verify_replication.sh` |
| **Consistency vs latency** | Asynchronous (default) vs synchronous `remote_apply` | `scripts/enable_sync_replication.sh on|off` |
| **Failover** | Manual promotion with `pg_promote()` | `verify_replication.sh --failover` |
| **Sharding / partitioning** | Range partitions by year; hash partitions by `customer_id` as a 4-shard simulation | `sql/01_partitioning_and_sharding.sql` |
| **MongoDB availability** | Optional 3-node replica set with automatic election | `scripts/init_mongo_replicaset.sh` |
| **Cloud deployment** | Reference architecture and decisions | `CLOUD_DESIGN.md` |

## Run
```bash
docker compose up -d primary replica          # first start builds the database (~1–2 min), then the replica clones it
./portfolio-5-distributed-cloud/scripts/verify_replication.sh        # needs psql; set PGPASSWORD=ap_password
PGPASSWORD=ap_password psql -h localhost -p 5432 -U postgres -d access_pensions \
   -f portfolio-5-distributed-cloud/sql/01_partitioning_and_sharding.sql
```
`verify_replication.sh` defaults: host `localhost`, primary port 5432, replica port 5433, user `postgres`.

## Honest scope note
Partitioning here runs on one node: it demonstrates shard-key routing and pruning, not multi-node sharding. A real multi-node deployment would use Citus/`postgres_fdw` (PostgreSQL) or a sharded MongoDB cluster – discussed in `CLOUD_DESIGN.md`.
