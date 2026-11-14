-- =====================================================================
-- MIT 8103 | Portfolio 1 | Access Pensions Limited (simulated case study)
-- 01_schema.sql : schema, types, tables, keys and constraints (PostgreSQL 16)
-- NOTE: all data in this project is synthetic. No real customer data is used.
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;   -- hide DROP ... CASCADE notices

DROP SCHEMA IF EXISTS ap CASCADE;
CREATE SCHEMA ap;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;   -- used in Portfolio 2 (fuzzy name search)
SET search_path = ap, public;

-- Make the schema the default for every new session on this database
DO $$ BEGIN
  EXECUTE format('ALTER DATABASE %I SET search_path = ap, public', current_database());
END $$;

-- ---------- Enumerated types (controlled vocabularies) ----------
CREATE TYPE customer_status      AS ENUM ('ACTIVE', 'RETIRED', 'DECEASED');
CREATE TYPE txn_type             AS ENUM ('CONTRIBUTION', 'PAYMENT');          -- Inflow / Outflow
CREATE TYPE contribution_source  AS ENUM ('EMPLOYEE', 'EMPLOYER', 'VOLUNTARY');
CREATE TYPE benefit_type         AS ENUM ('25_PERCENT_WITHDRAWAL', 'EQUITY_MORTGAGE_WITHDRAWAL',
                                          'LUMP_SUM_WITHDRAWAL', 'VOLUNTARY_WITHDRAWAL',
                                          'DEATH_BENEFIT_WITHDRAWAL');
CREATE TYPE benefit_status       AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'PAID');

-- ---------- Reference (lookup) tables ----------
CREATE TABLE fund_type (
    fund_type_id  SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fund_code     VARCHAR(10) NOT NULL UNIQUE,
    fund_name     VARCHAR(60) NOT NULL,
    risk_profile  VARCHAR(20) NOT NULL
);

CREATE TABLE employer (
    employer_id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employer_name  VARCHAR(150) NOT NULL UNIQUE,
    sector         VARCHAR(60)  NOT NULL
);

CREATE TABLE bank (
    bank_id    SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bank_name  VARCHAR(80) NOT NULL UNIQUE
);

-- ---------- Customer biodata ----------
CREATE TABLE customer (
    customer_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pension_pin        CHAR(15)     NOT NULL UNIQUE,
    surname            VARCHAR(60)  NOT NULL,
    first_name         VARCHAR(60)  NOT NULL,
    other_names        VARCHAR(100),
    date_of_birth      DATE         NOT NULL,
    gender             CHAR(1)      NOT NULL,
    phone_number       VARCHAR(15)  NOT NULL,
    email              VARCHAR(120),
    account_created_on DATE         NOT NULL DEFAULT CURRENT_DATE,
    fund_type_id       SMALLINT     NOT NULL REFERENCES fund_type (fund_type_id),
    employer_id        INTEGER      NOT NULL REFERENCES employer (employer_id),  -- current or last employer
    bank_id            SMALLINT     NOT NULL REFERENCES bank (bank_id),
    bank_account_no    CHAR(10)     NOT NULL,
    denomination       CHAR(3)      NOT NULL DEFAULT 'NGN',                      -- ISO 4217 currency code
    status             customer_status NOT NULL DEFAULT 'ACTIVE',
    current_balance    NUMERIC(18,2) NOT NULL DEFAULT 0,                         -- maintained ONLY by ledger trigger
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_customer_bank_account UNIQUE (bank_id, bank_account_no),
    CONSTRAINT ck_pin_format     CHECK (pension_pin ~ '^PEN[0-9]{12}$'),
    CONSTRAINT ck_gender         CHECK (gender IN ('M', 'F')),
    CONSTRAINT ck_phone_format   CHECK (phone_number ~ '^(\+234|0)[0-9]{10}$'),
    CONSTRAINT ck_email_format   CHECK (email IS NULL OR email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    CONSTRAINT ck_account_no     CHECK (bank_account_no ~ '^[0-9]{10}$'),          -- NUBAN length
    CONSTRAINT ck_denomination   CHECK (denomination ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_dob            CHECK (date_of_birth > DATE '1900-01-01'),
    CONSTRAINT ck_balance_nonneg CHECK (current_balance >= 0)
);

CREATE TABLE next_of_kin (
    nok_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   BIGINT       NOT NULL REFERENCES customer (customer_id) ON DELETE CASCADE,
    full_name     VARCHAR(120) NOT NULL,
    relationship  VARCHAR(30)  NOT NULL,
    phone_number  VARCHAR(15)  NOT NULL,
    share_percent NUMERIC(5,2) NOT NULL DEFAULT 100 CHECK (share_percent > 0 AND share_percent <= 100)
);

-- ---------- Benefit applications ----------
CREATE TABLE benefit_application (
    benefit_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id             BIGINT        NOT NULL REFERENCES customer (customer_id),
    benefit_type            benefit_type  NOT NULL,
    application_date        DATE          NOT NULL DEFAULT CURRENT_DATE,
    amount_requested        NUMERIC(18,2) NOT NULL CHECK (amount_requested > 0),
    amount_approved         NUMERIC(18,2) CHECK (amount_approved > 0),
    status                  benefit_status NOT NULL DEFAULT 'PENDING',
    decision_date           DATE,
    decided_by              VARCHAR(60),
    rejection_reason        TEXT,
    supporting_document_ref VARCHAR(60),
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_approved_amount CHECK ((status IN ('APPROVED', 'PAID')) = (amount_approved IS NOT NULL)),
    CONSTRAINT ck_reject_reason   CHECK (status <> 'REJECTED' OR rejection_reason IS NOT NULL),
    CONSTRAINT ck_decision        CHECK (status = 'PENDING' OR (decision_date IS NOT NULL AND decided_by IS NOT NULL))
);

-- ---------- Transaction ledger (inflow = CONTRIBUTION, outflow = PAYMENT) ----------
CREATE TABLE account_transaction (
    txn_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id         BIGINT        NOT NULL REFERENCES customer (customer_id),
    txn_type            txn_type      NOT NULL,
    contribution_source contribution_source,
    amount              NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    txn_date            DATE          NOT NULL DEFAULT CURRENT_DATE,
    employer_id         INTEGER       REFERENCES employer (employer_id),   -- paying employer (contributions)
    benefit_id          BIGINT        REFERENCES benefit_application (benefit_id),  -- originating benefit (payments)
    reference           VARCHAR(40)   NOT NULL UNIQUE,
    balance_after       NUMERIC(18,2) NOT NULL,                            -- running balance, set by trigger
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_txn_shape CHECK (
        (txn_type = 'CONTRIBUTION' AND contribution_source IS NOT NULL AND benefit_id IS NULL
            AND (contribution_source = 'VOLUNTARY' OR employer_id IS NOT NULL))
     OR (txn_type = 'PAYMENT' AND contribution_source IS NULL AND benefit_id IS NOT NULL AND employer_id IS NULL)
    ),
    CONSTRAINT ck_balance_after_nonneg CHECK (balance_after >= 0)
);

-- ---------- Audit trail ----------
CREATE TABLE audit_log (
    audit_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name  TEXT        NOT NULL,
    record_pk   TEXT        NOT NULL,
    action      TEXT        NOT NULL,
    old_data    JSONB,
    new_data    JSONB,
    changed_by  TEXT        NOT NULL DEFAULT current_user,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  customer IS 'Customer biodata and RSA account (one RSA per customer).';
COMMENT ON COLUMN customer.current_balance IS 'Controlled denormalisation: updated only by fn_post_transaction().';
COMMENT ON COLUMN account_transaction.balance_after IS 'Running balance after this posting; derived by trigger, never supplied by users.';
COMMENT ON TABLE  account_transaction IS 'Append-only ledger. UPDATE/DELETE are blocked by trigger.';
