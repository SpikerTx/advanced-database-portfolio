-- =====================================================================
-- Portfolio 4 | PostgreSQL JSONB (document model inside the relational engine)
--  1) v_customer_document : a "customer 360" document assembled from relational tables
--  2) benefit_details     : polymorphic, type-specific benefit attributes stored as JSONB + GIN index
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;
SET search_path = ap, public;

-- 1) Customer document view (same shape as the MongoDB `customers` collection)
CREATE OR REPLACE VIEW v_customer_document AS
SELECT c.customer_id,
       jsonb_build_object(
         '_id',        c.pension_pin,
         'name',       jsonb_build_object('surname', c.surname, 'firstName', c.first_name, 'otherNames', c.other_names),
         'contact',    jsonb_build_object('phone', c.phone_number, 'email', c.email),
         'fund',       jsonb_build_object('code', f.fund_code, 'name', f.fund_name),
         'employer',   jsonb_build_object('name', e.employer_name, 'sector', e.sector),
         'bank',       jsonb_build_object('name', b.bank_name, 'accountNo', c.bank_account_no),
         'denomination', c.denomination,
         'status',     c.status,
         'currentBalance', c.current_balance,
         'nextOfKin',  COALESCE((SELECT jsonb_agg(jsonb_build_object('fullName', n.full_name, 'relationship', n.relationship,
                                                                    'sharePercent', n.share_percent) ORDER BY n.nok_id)
                                   FROM next_of_kin n WHERE n.customer_id = c.customer_id), '[]'::jsonb),
         'recentTransactions', COALESCE((SELECT jsonb_agg(jsonb_build_object('date', t.txn_date, 'type', t.txn_type,
                                                          'amount', t.amount, 'balanceAfter', t.balance_after)
                                                          ORDER BY t.txn_id DESC)
                                   FROM (SELECT * FROM account_transaction x WHERE x.customer_id = c.customer_id
                                          ORDER BY x.txn_id DESC LIMIT 5) t), '[]'::jsonb)
       ) AS doc
FROM customer c
JOIN fund_type f USING (fund_type_id)
JOIN employer  e USING (employer_id)
JOIN bank      b USING (bank_id);

-- 2) Polymorphic benefit details: each benefit type carries different attributes
DROP TABLE IF EXISTS benefit_details;
CREATE TABLE benefit_details (
    benefit_id BIGINT PRIMARY KEY REFERENCES benefit_application (benefit_id) ON DELETE CASCADE,
    details    JSONB NOT NULL
);

INSERT INTO benefit_details (benefit_id, details)
SELECT ba.benefit_id,
       CASE ba.benefit_type
         WHEN '25_PERCENT_WITHDRAWAL' THEN
              jsonb_build_object('reason', 'Unemployment', 'monthsUnemployed', 4 + ba.benefit_id % 9)
         WHEN 'EQUITY_MORTGAGE_WITHDRAWAL' THEN
              jsonb_build_object('lender', (ARRAY['Federal Mortgage Bank','Sterling Mortgage','Haven Housing Finance'])[1 + ba.benefit_id % 3],
                                 'propertyState', (ARRAY['Lagos','Abuja FCT','Rivers','Oyo','Kano'])[1 + ba.benefit_id % 5],
                                 'offerLetterRef', 'OFR-' || lpad(ba.benefit_id::text, 7, '0'))
         WHEN 'LUMP_SUM_WITHDRAWAL' THEN
              jsonb_build_object('retirementOption', (ARRAY['Programmed Withdrawal','Annuity'])[1 + ba.benefit_id % 2],
                                 'retirementDate', ba.application_date - 30)
         WHEN 'VOLUNTARY_WITHDRAWAL' THEN
              jsonb_build_object('purpose', (ARRAY['Education','Medical','Business'])[1 + ba.benefit_id % 3])
         ELSE
              jsonb_build_object('deathCertificateNo', 'DC-' || lpad(ba.benefit_id::text, 8, '0'),
                                 'claimants', COALESCE((SELECT jsonb_agg(jsonb_build_object('name', n.full_name, 'share', n.share_percent))
                                                          FROM next_of_kin n WHERE n.customer_id = ba.customer_id), '[]'::jsonb))
       END
FROM benefit_application ba;

CREATE INDEX idx_benefit_details_gin ON benefit_details USING gin (details jsonb_path_ops);
ANALYZE benefit_details;
