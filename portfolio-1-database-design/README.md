# Portfolio 1 – Database Design and Modelling

**Case study:** Access Pensions Limited – a pension fund administrator. Users: customer-service staff, benefits officers, internal auditors, employers (read-only reports). Major data: customer biodata, contribution/payment ledger, benefit applications. Key operations: onboard customer, post contribution, apply for / approve / pay a benefit, produce statements and audit reports.

| Artefact | File |
|---|---|
| ER diagram | `er-diagram/access_pensions_er.png`, `er-diagram/ER_DIAGRAM.md` (Mermaid) |
| Relational schema, keys, constraints | `sql/01_schema.sql` |
| Business rules, triggers, workflow functions | `sql/02_functions_triggers.sql` |
| Synthetic data generator | `sql/03_seed_data.sql` |
| Views, masking, roles | `sql/04_views_security.sql` |
| Normalisation explanation | `normalisation.md` |

## Design highlights
* 8 tables: `customer`, `fund_type`, `employer`, `bank`, `next_of_kin`, `account_transaction`, `benefit_application`, `audit_log`.
* Spec fields → columns: Surname, First name, Other names, Date of account creation (`account_created_on`), Fund type (`fund_type_id`), Phone, Email, Pensions PIN (`pension_pin`), Name of employer, Bank name, Bank account no, Denomination (ISO currency code, default `NGN`).
* **Added features:** date of birth/gender, next of kin (needed for death benefit), customer status, workflow status and approver on benefit applications, audit log, masked view and database roles (`ap_auditor`, `ap_benefits_officer`, `ap_customer_service`).
* **Business rules (simplified, academic):** 25 % withdrawal and equity-mortgage capped at 25 % of balance; lump sum only for RETIRED customers; death benefit only for DECEASED customers; one 25 % withdrawal per customer; overdrafts rejected. Confirm against PRA 2014 / PenCom guidelines before any real use.
* All data is synthetic – no real customers, employers or accounts.

## How it was tested
`scripts/verify_build.sql` runs at the end of every build: customer balances must equal the last ledger balance, every running balance must equal an independent recomputation, no negative balances, every PAID benefit must have a ledger payment (all must return 0 violations).
