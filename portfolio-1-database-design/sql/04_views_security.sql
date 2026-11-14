-- =====================================================================
-- 04_views_security.sql : reporting views, data masking and role-based access
-- =====================================================================
\set ON_ERROR_STOP on
SET search_path = ap, public;

-- ---------- Views ----------
-- Full customer profile in the same column order as the case-study specification
CREATE OR REPLACE VIEW v_customer_profile AS
SELECT c.customer_id, c.surname, c.first_name, c.other_names, c.account_created_on AS date_of_account_creation,
       f.fund_name AS fund_type, c.phone_number, c.email, c.pension_pin,
       e.employer_name AS name_of_employer, b.bank_name, c.bank_account_no, c.denomination,
       c.status, c.current_balance
FROM customer c
JOIN fund_type f USING (fund_type_id)
JOIN employer  e USING (employer_id)
JOIN bank      b USING (bank_id);

-- Masked view for customer-service staff (PII minimisation)
CREATE OR REPLACE VIEW v_customer_masked AS
SELECT customer_id,
       left(pension_pin, 6) || '******' || right(pension_pin, 3)              AS pension_pin_masked,
       surname, first_name,
       left(phone_number, 4) || '****' || right(phone_number, 3)              AS phone_masked,
       regexp_replace(email, '(^.).*(@.*$)', '\1***\2')                       AS email_masked,
       status
FROM customer;

CREATE OR REPLACE VIEW v_pending_benefits AS
SELECT ba.benefit_id, ba.benefit_type, ba.application_date, ba.amount_requested,
       c.customer_id, c.surname || ' ' || c.first_name AS customer_name, c.current_balance, c.status AS customer_status
FROM benefit_application ba JOIN customer c USING (customer_id)
WHERE ba.status = 'PENDING';

-- ---------- Roles (cluster-level; created only if missing) ----------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ap_auditor')          THEN CREATE ROLE ap_auditor          NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ap_benefits_officer') THEN CREATE ROLE ap_benefits_officer NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ap_customer_service') THEN CREATE ROLE ap_customer_service NOLOGIN; END IF;
END $$;

GRANT USAGE ON SCHEMA ap TO ap_auditor, ap_benefits_officer, ap_customer_service;

-- Auditor: read-only everywhere (segregation of duties: no write path)
GRANT SELECT ON ALL TABLES IN SCHEMA ap TO ap_auditor;

-- Benefits officer: read customer/benefit data, act only through the workflow functions
REVOKE EXECUTE ON FUNCTION submit_benefit_application(BIGINT, benefit_type, NUMERIC, VARCHAR),
                           approve_benefit(BIGINT, TEXT, NUMERIC),
                           reject_benefit(BIGINT, TEXT, TEXT),
                           pay_benefit(BIGINT) FROM PUBLIC;
GRANT SELECT ON customer, benefit_application, next_of_kin, account_transaction, v_pending_benefits TO ap_benefits_officer;
GRANT EXECUTE ON FUNCTION submit_benefit_application(BIGINT, benefit_type, NUMERIC, VARCHAR),
                          approve_benefit(BIGINT, TEXT, NUMERIC),
                          reject_benefit(BIGINT, TEXT, TEXT),
                          pay_benefit(BIGINT) TO ap_benefits_officer;

-- Customer service: masked view only
GRANT SELECT ON v_customer_masked TO ap_customer_service;
