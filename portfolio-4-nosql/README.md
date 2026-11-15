# Portfolio 4 – NoSQL and Advanced Data Models

**Model chosen: document (MongoDB 7)**, plus PostgreSQL **JSONB** as a hybrid option. Same case study (Access Pensions Limited).

## Why documents fit part of this domain
| Data | Fit | Reason |
|---|---|---|
| Customer profile ("customer 360") | Good | Read together: biodata + employer + bank + next of kin + last transactions → one document read, no joins |
| Benefit applications | Very good | **Polymorphic**: equity-mortgage has lender/property, death benefit has claimants, 25 % has unemployment months. Documents hold different `details` shapes without nullable columns |
| Core ledger and balances | Poor | Needs multi-row ACID, constraints, immutability, reconciliation → stays in PostgreSQL |

Patterns used: **embedding** (next of kin), **subset pattern** (last 5 transactions embedded; full history stays in the ledger), **polymorphic pattern** (`details`), schema validation (`$jsonSchema`), `Decimal128` for money.

## Run MongoDB (Docker)
```bash
docker compose up -d mongo            # seed script runs automatically on first start
docker compose exec mongo mongosh access_pensions --file /scripts/queries.js
```
No Docker? Install MongoDB + `mongosh`, then:
`mongosh --file portfolio-4-nosql/mongodb/init/01_seed_access_pensions.js` and `mongosh access_pensions --file portfolio-4-nosql/mongodb/queries.js`.

## PostgreSQL JSONB (built automatically)
`postgres-jsonb/01_jsonb_documents.sql` creates `v_customer_document` (relational → document) and `benefit_details` with a GIN index; `02_jsonb_queries.sql` shows containment, path, aggregation and plan evidence.
```bash
psql -d access_pensions -f portfolio-4-nosql/postgres-jsonb/02_jsonb_queries.sql
```
Save screenshots/logs to `results/`.
