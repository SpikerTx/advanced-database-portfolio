-- =====================================================================
-- Portfolio 2 | 01_create_indexes.sql : optimisation structures
-- (Primary-key / unique-constraint indexes already exist from Portfolio 1)
-- =====================================================================
\set ON_ERROR_STOP on
SET search_path = ap, public;

-- Customer statement: equality on customer, range/sort on date; INCLUDE makes it index-only for the statement columns
CREATE INDEX IF NOT EXISTS idx_txn_customer_date
    ON account_transaction (customer_id, txn_date DESC, txn_id DESC)
    INCLUDE (txn_type, contribution_source, amount, balance_after);

-- Employer remittance reports (partial index: contributions only)
CREATE INDEX IF NOT EXISTS idx_txn_employer_date
    ON account_transaction (employer_id, txn_date) WHERE txn_type = 'CONTRIBUTION';

-- Foreign-key support indexes (joins / cascades)
CREATE INDEX IF NOT EXISTS idx_txn_benefit       ON account_transaction (benefit_id) WHERE benefit_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_benefit_customer  ON benefit_application (customer_id);
CREATE INDEX IF NOT EXISTS idx_nok_customer      ON next_of_kin (customer_id);

-- Lookups and search
CREATE INDEX IF NOT EXISTS idx_customer_phone        ON customer (phone_number);
CREATE INDEX IF NOT EXISTS idx_customer_surname_trgm ON customer USING gin (surname gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_customer_fund_balance ON customer (fund_type_id, current_balance DESC);

-- Work-queue index: only PENDING applications are indexed (small and hot)
CREATE INDEX IF NOT EXISTS idx_benefit_pending ON benefit_application (application_date) WHERE status = 'PENDING';

-- Pre-aggregated monthly contributions per employer (refresh on a schedule)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_monthly_contributions AS
SELECT employer_id, date_trunc('month', txn_date)::date AS month, SUM(amount) AS total_contributions, COUNT(*) AS postings
FROM account_transaction
WHERE txn_type = 'CONTRIBUTION' AND employer_id IS NOT NULL
GROUP BY employer_id, date_trunc('month', txn_date)::date;
CREATE UNIQUE INDEX IF NOT EXISTS uq_mv_monthly_contributions ON mv_monthly_contributions (employer_id, month);

ANALYZE;
