# Cloud and Distributed Design – Access Pensions Limited

*Design discussion (not a deployed environment). Adjust product names, regions and limits to the provider's current documentation.*

## 1. Workload characteristics
* Ledger writes: monthly employer remittances arrive in bursts (around the 28th); benefit payments are low-volume, high-value, and must never overdraw.
* Reads: customer statements, call-centre lookups, regulator/audit reports.
* Data sensitivity: personal data and pension balances – subject to Nigerian data-protection law (NDPA 2023) and PenCom requirements. **Region choice and cross-border transfer must be confirmed with the Compliance/Legal teams.**

## 2. Reference architecture
| Layer | Choice | Rationale |
|---|---|---|
| Ledger / system of record | Managed PostgreSQL, Multi-AZ primary with synchronous standby in a second zone | Strong consistency, automatic failover, point-in-time recovery |
| Read scaling | 1–2 asynchronous read replicas | Statements and reports off the primary; tolerate seconds of lag |
| Customer-360 / workflow documents | Managed MongoDB replica set (3 nodes across zones) | Flexible polymorphic benefit data; election gives automatic failover |
| Cache (optional) | Key-value store (e.g. Redis) for session and statement-page caching | Reduces read load; never the source of truth for balances |
| Backup / DR | Daily snapshots + WAL archiving; cross-region copy only if residency rules allow | RPO ≈ minutes, RTO ≈ tens of minutes (targets to be agreed) |

## 3. Consistency and availability decisions (CAP / PACELC)
* **Ledger = CP-leaning:** payments go only to the primary; synchronous commit (`remote_apply`) to a standby trades some latency for zero data loss on failover. Reads that must reflect a just-posted payment go to the primary.
* **Reporting = AP-leaning:** replicas may lag; dashboards show "as of" time.
* **MongoDB:** write concern `majority` for benefit decisions; `readConcern: majority` for approvals; secondary reads only for non-critical views.

## 4. Sharding strategy (when one node is not enough)
* Shard key `customer_id` (hash): even distribution, and customer-centric queries (statement, balance, payment) hit one shard (demonstrated in `01_partitioning_and_sharding.sql`).
* Cross-shard queries (company-wide totals) fan out to all shards → serve from pre-aggregated tables/materialised views.
* Range partitioning by `txn_date` is applied inside each shard for retention/archival.

## 5. Security and governance
Encryption at rest and in transit (TLS), network isolation (private subnets), least-privilege roles (see Portfolio 1), audit logging, secrets in a vault (never in the repository – use `.env`, which is git-ignored), masked views for non-privileged staff.

## 6. Operational runbook (summary)
1. Monitor `pg_stat_replication` lag and disk/WAL growth.
2. Failover: promote standby, repoint the application endpoint, rebuild the old primary as a replica (`verify_replication.sh --failover` demonstrates promotion).
3. Test restores quarterly and record RPO/RTO achieved.
