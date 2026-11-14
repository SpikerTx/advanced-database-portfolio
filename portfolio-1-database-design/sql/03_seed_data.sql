-- =====================================================================
-- 03_seed_data.sql : deterministic SYNTHETIC data (no real people, employers or accounts)
-- Scale with:  psql -v customers=50000 -f 03_seed_data.sql   (default 20000)
-- =====================================================================
\set ON_ERROR_STOP on
SET search_path = ap, public;

\if :{?customers}
\else
  \set customers 20000
\endif

-- reproducible pseudo-random data
SELECT setseed(0.2026) AS seeded \gset

-- ---------- Reference data ----------
INSERT INTO fund_type (fund_code, fund_name, risk_profile) VALUES
 ('RSA_I',   'RSA Fund I',         'Aggressive'),
 ('RSA_II',  'RSA Fund II',        'Moderate'),
 ('RSA_III', 'RSA Fund III',       'Conservative'),
 ('RSA_IV',  'RSA Fund IV',        'Retiree'),
 ('MPF',     'Micro Pension Fund', 'Micro');

INSERT INTO bank (bank_name) VALUES
 ('Access Bank'), ('Zenith Bank'), ('Guaranty Trust Bank'), ('First Bank of Nigeria'),
 ('United Bank for Africa'), ('Fidelity Bank'), ('Stanbic IBTC Bank'), ('Sterling Bank'),
 ('Wema Bank'), ('Union Bank'), ('Polaris Bank'), ('Ecobank Nigeria'), ('FCMB'), ('Keystone Bank');

-- Fictional employers (any resemblance to real organisations is coincidental)
INSERT INTO employer (employer_name, sector) VALUES
 ('Atlas Freight Nigeria Ltd','Logistics'), ('Bluewater Offshore Services Ltd','Oil & Gas'),
 ('Cedar Hill Microfinance Bank','Financial Services'), ('Delta Grain Mills Ltd','Agro-processing'),
 ('Eko Metro Transit Services','Transport'), ('Federal Works Directorate (Simulated)','Public Sector'),
 ('Greenfield Pharma Nigeria Ltd','Healthcare'), ('Harbour Point Terminals Ltd','Maritime'),
 ('Ibadan Teaching Services Board (Simulated)','Education'), ('Jos Plateau Minerals Ltd','Mining'),
 ('Kano Textile Works Ltd','Manufacturing'), ('Lekki Heights Properties Ltd','Real Estate'),
 ('Mainland Insurance Brokers Ltd','Insurance'), ('Niger Basin Power Ltd','Energy'),
 ('Oriental Telecom Nigeria Ltd','Telecoms'), ('Pearl Hospitality Group','Hospitality'),
 ('Quest Software Systems Ltd','Technology'), ('Rivers Petrochem Services Ltd','Oil & Gas'),
 ('Savanna Cement Company Ltd','Manufacturing'), ('Trident Security Services Ltd','Security'),
 ('Unity State Health Board (Simulated)','Public Sector'), ('Vista Retail Stores Ltd','Retail'),
 ('Westgate Construction Ltd','Construction'), ('Xcel Media Networks Ltd','Media'),
 ('Yola Agro Cooperative','Agriculture'), ('Zenith Ridge Consulting Ltd','Consulting'),
 ('Abuja Capital Markets Ltd','Financial Services'), ('Benue Valley Farms Ltd','Agriculture'),
 ('Calabar Port Logistics Ltd','Logistics'), ('Dutse Water Resources Board (Simulated)','Public Sector');

-- Disable user triggers for the bulk load only (ledger balances are computed with a window function)
ALTER TABLE customer            DISABLE TRIGGER USER;
ALTER TABLE account_transaction DISABLE TRIGGER USER;

-- ---------- Customers ----------
INSERT INTO customer (pension_pin, surname, first_name, other_names, date_of_birth, gender, phone_number,
                      email, account_created_on, fund_type_id, employer_id, bank_id, bank_account_no, status)
WITH names AS (
  SELECT ARRAY['Okafor','Adeyemi','Bello','Eze','Ibrahim','Okonkwo','Balogun','Udoh','Nwosu','Abubakar',
               'Adebayo','Chukwu','Musa','Ogunleye','Danjuma','Afolabi','Yakubu','Obi','Lawal','Akpan',
               'Ojo','Umar','Onyeama','Salisu','Ezekwesili','Olawale','Mohammed','Etim','Nnadi','Fashola'] AS sur,
         ARRAY['Chinedu','Tunde','Musa','Emeka','Ibrahim','Segun','Kelechi','Yusuf','Femi','Obinna',
               'Sani','Ayodele','Uche','Bashir','Kunle'] AS male,
         ARRAY['Ngozi','Amina','Funke','Chiamaka','Zainab','Bukola','Ifeoma','Hauwa','Yetunde','Adaeze',
               'Aisha','Folake','Nneka','Halima','Temitope'] AS female,
         ARRAY['Oluwaseun','Chukwuemeka','Abdulkadir','Ifeanyi','Olamide','Nkechi','Babatunde','Ugochukwu'] AS oth,
         ARRAY['803','806','810','813','816','703','706','708','802','805','809'] AS pfx,
         ARRAY['gmail.com','yahoo.com','outlook.com'] AS dom
), base AS (
  SELECT g, random() AS r_status, random() AS r_sur, random() AS r_first, random() AS r_other, random() AS r_age,
         random() AS r_gender, random() AS r_fund, random() AS r_emp, random() AS r_bank, random() AS r_created,
         random() AS r_mob, random() AS r_dom
  FROM generate_series(1, :customers) g
), typed AS (
  SELECT b.*, CASE WHEN r_status < 0.03 THEN 'DECEASED' WHEN r_status < 0.15 THEN 'RETIRED' ELSE 'ACTIVE' END::customer_status AS st
  FROM base b
)
SELECT 'PEN' || lpad((100000000000 + t.g)::text, 12, '0'),
       n.sur[1 + floor(t.r_sur * array_length(n.sur, 1))::int],
       CASE WHEN t.r_gender < 0.5 THEN n.male[1 + floor(t.r_first * array_length(n.male, 1))::int]
            ELSE n.female[1 + floor(t.r_first * array_length(n.female, 1))::int] END,
       CASE WHEN t.r_other < 0.6 THEN n.oth[1 + floor(t.r_other / 0.6 * array_length(n.oth, 1))::int] END,
       CASE t.st WHEN 'ACTIVE'   THEN CURRENT_DATE - ((25 + t.r_age * 30) * 365)::int
                 WHEN 'RETIRED'  THEN CURRENT_DATE - ((60 + t.r_age * 15) * 365)::int
                 ELSE                 CURRENT_DATE - ((55 + t.r_age * 25) * 365)::int END,
       CASE WHEN t.r_gender < 0.5 THEN 'M' ELSE 'F' END,
       '0' || n.pfx[1 + floor(t.r_mob * array_length(n.pfx, 1))::int] || lpad(((t.g * 7919) % 10000000)::text, 7, '0'),
       CASE WHEN t.r_dom > 0.92 THEN NULL
            ELSE lower((CASE WHEN t.r_gender < 0.5 THEN n.male[1 + floor(t.r_first * array_length(n.male, 1))::int]
                             ELSE n.female[1 + floor(t.r_first * array_length(n.female, 1))::int] END)
                       || '.' || n.sur[1 + floor(t.r_sur * array_length(n.sur, 1))::int])
                 || t.g || '@' || n.dom[1 + floor(t.r_dom / 0.92 * array_length(n.dom, 1))::int] END,
       CASE t.st WHEN 'ACTIVE' THEN CURRENT_DATE - (60 + t.r_created * 720)::int
                 ELSE CURRENT_DATE - (365 + t.r_created * 700)::int END,
       CASE WHEN t.st <> 'ACTIVE' THEN 4
            WHEN t.r_fund < 0.25 THEN 1 WHEN t.r_fund < 0.75 THEN 2 WHEN t.r_fund < 0.97 THEN 3 ELSE 5 END,
       1 + floor(t.r_emp  * (SELECT count(*) FROM employer))::int,
       1 + floor(t.r_bank * (SELECT count(*) FROM bank))::int,
       lpad((((t.g::bigint * 7919 + 1000000007) % 9000000000) + 1000000000)::text, 10, '0'),   -- unique 10-digit NUBAN-style number
       t.st
FROM typed t CROSS JOIN names n;

-- ---------- Next of kin ----------
INSERT INTO next_of_kin (customer_id, full_name, relationship, phone_number, share_percent)
SELECT customer_id,
       (ARRAY['Adaeze','Tolu','Hassan','Ngozi','Bayo','Amaka'])[1 + customer_id % 6] || ' ' || surname,
       (ARRAY['Spouse','Child','Sibling','Parent'])[1 + customer_id % 4],
       '0' || (ARRAY['803','806','810','813','816'])[1 + customer_id % 5] || lpad(((customer_id * 104729) % 10000000)::text, 7, '0'),
       CASE WHEN customer_id % 10 < 3 THEN 60 ELSE 100 END
FROM customer;

INSERT INTO next_of_kin (customer_id, full_name, relationship, phone_number, share_percent)
SELECT customer_id, 'Chidi ' || surname, 'Child',
       '0' || (ARRAY['703','706','708'])[1 + customer_id % 3] || lpad(((customer_id * 15485863) % 10000000)::text, 7, '0'), 40
FROM customer WHERE customer_id % 10 < 3;

-- ---------- Contribution ledger (inflows) ----------
CREATE TEMP TABLE tmp_ledger ON COMMIT PRESERVE ROWS AS
WITH cust AS (
  SELECT customer_id, employer_id, status, random() AS r_sal,
         (date_trunc('month', account_created_on) + interval '1 month')::date AS first_month,
         (date_trunc('month', CURRENT_DATE) - CASE WHEN status = 'ACTIVE' THEN interval '1 month'
                                                   ELSE interval '4 months' END)::date AS last_month
  FROM customer
), m AS (
  SELECT c.customer_id, c.employer_id, c.status,
         round((18000 + c.r_sal * 162000)::numeric, 2) AS monthly_total,           -- 18% of salary: NGN 18k - 180k
         ((c.first_month + (k * interval '1 month'))::date + 27) AS txn_date      -- posted on the 28th
  FROM cust c
  CROSS JOIN LATERAL generate_series(0,
        (EXTRACT(YEAR FROM c.last_month) * 12 + EXTRACT(MONTH FROM c.last_month)
       - EXTRACT(YEAR FROM c.first_month) * 12 - EXTRACT(MONTH FROM c.first_month))::int) AS k
)
SELECT customer_id, 'CONTRIBUTION'::txn_type AS txn_type, 'EMPLOYEE'::contribution_source AS src,
       round(monthly_total * 8 / 18, 2) AS amount, txn_date, employer_id, 1 AS src_rank FROM m
UNION ALL
SELECT customer_id, 'CONTRIBUTION', 'EMPLOYER', round(monthly_total * 10 / 18, 2), txn_date, employer_id, 2 FROM m
UNION ALL
SELECT customer_id, 'CONTRIBUTION', 'VOLUNTARY', round((5000 + random() * 95000)::numeric, 2), txn_date, NULL, 3
FROM m WHERE status = 'ACTIVE' AND random() < 0.04;

INSERT INTO account_transaction (customer_id, txn_type, contribution_source, amount, txn_date, employer_id,
                                 reference, balance_after)
SELECT customer_id, txn_type, src, amount, txn_date, employer_id,
       'CTR-' || lpad(rn::text, 10, '0'),
       SUM(amount) OVER (PARTITION BY customer_id ORDER BY rn)
FROM (SELECT l.*, row_number() OVER (ORDER BY txn_date, customer_id, src_rank) AS rn FROM tmp_ledger l) x
ORDER BY rn;

UPDATE customer c SET current_balance = t.balance_after
FROM (SELECT DISTINCT ON (customer_id) customer_id, balance_after
        FROM account_transaction ORDER BY customer_id, txn_id DESC) t
WHERE c.customer_id = t.customer_id;

DROP TABLE tmp_ledger;

ALTER TABLE customer            ENABLE TRIGGER USER;
ALTER TABLE account_transaction ENABLE TRIGGER USER;

-- ---------- Benefit applications and payments (outflows) via the real workflow functions ----------
DO $$
DECLARE
    r RECORD; v_type benefit_type; v_cap NUMERIC; v_amt NUMERIC; v_id BIGINT; v_roll DOUBLE PRECISION;
BEGIN
    FOR r IN SELECT customer_id, status FROM customer WHERE current_balance > 0 ORDER BY customer_id LOOP
        v_roll := random();
        v_type := NULL;
        IF r.status = 'ACTIVE' THEN
            IF    v_roll < 0.04 THEN v_type := '25_PERCENT_WITHDRAWAL';
            ELSIF v_roll < 0.07 THEN v_type := 'EQUITY_MORTGAGE_WITHDRAWAL';
            ELSIF v_roll < 0.09 THEN v_type := 'VOLUNTARY_WITHDRAWAL';
            END IF;
        ELSIF r.status = 'RETIRED'  AND v_roll < 0.60 THEN v_type := 'LUMP_SUM_WITHDRAWAL';
        ELSIF r.status = 'DECEASED' AND v_roll < 0.80 THEN v_type := 'DEATH_BENEFIT_WITHDRAWAL';
        END IF;
        CONTINUE WHEN v_type IS NULL;

        v_cap := fn_benefit_cap(r.customer_id, v_type);
        v_amt := CASE WHEN v_type = 'DEATH_BENEFIT_WITHDRAWAL' THEN v_cap
                      ELSE round(v_cap * (0.5 + random()::numeric * 0.5), 2) END;
        IF v_amt <= 0 THEN CONTINUE; END IF;

        INSERT INTO benefit_application (customer_id, benefit_type, application_date, amount_requested, supporting_document_ref)
        VALUES (r.customer_id, v_type, CURRENT_DATE - (random() * 90)::int, v_amt,
                'DOC-' || lpad(r.customer_id::text, 8, '0'))
        RETURNING benefit_id INTO v_id;

        v_roll := random();
        IF    v_roll < 0.15 THEN NULL;                                                  -- stays PENDING
        ELSIF v_roll < 0.25 THEN PERFORM reject_benefit(v_id, 'seed.officer', 'Incomplete supporting documents');
        ELSIF v_roll < 0.40 THEN PERFORM approve_benefit(v_id, 'seed.officer');          -- APPROVED, not yet paid
        ELSE  PERFORM approve_benefit(v_id, 'seed.officer'); PERFORM pay_benefit(v_id);  -- PAID
        END IF;
    END LOOP;
END $$;

ANALYZE;
