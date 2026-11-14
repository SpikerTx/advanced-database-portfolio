-- Removes every optimisation structure so the "before" baseline can be measured.
\set ON_ERROR_STOP on
SET client_min_messages = warning;
SET search_path = ap, public;
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_contributions;
DROP INDEX IF EXISTS idx_txn_customer_date, idx_txn_employer_date, idx_txn_benefit, idx_benefit_customer,
                     idx_nok_customer, idx_customer_phone, idx_customer_surname_trgm,
                     idx_customer_fund_balance, idx_benefit_pending;
ANALYZE;
