-- =====================================================================
-- 02_functions_triggers.sql : business logic, ledger posting, audit trail
-- =====================================================================
\set ON_ERROR_STOP on
SET search_path = ap, public;

-- ---------- 1. Ledger posting: compute running balance under a row lock ----------
CREATE OR REPLACE FUNCTION fn_post_transaction() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_balance NUMERIC(18,2);
    v_status  customer_status;
    v_new     NUMERIC(18,2);
BEGIN
    -- Row-level lock on the customer serialises concurrent postings for the SAME customer
    SELECT current_balance, status INTO v_balance, v_status
      FROM customer WHERE customer_id = NEW.customer_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer % does not exist', NEW.customer_id USING ERRCODE = 'foreign_key_violation';
    END IF;

    IF NEW.txn_type = 'CONTRIBUTION' THEN
        IF v_status = 'DECEASED' THEN
            RAISE EXCEPTION 'Contributions cannot be posted to a deceased customer (id %)', NEW.customer_id
                USING ERRCODE = 'check_violation';
        END IF;
        v_new := v_balance + NEW.amount;
    ELSE
        IF NEW.amount > v_balance THEN
            RAISE EXCEPTION 'Insufficient balance: requested %, available % (customer %)',
                NEW.amount, v_balance, NEW.customer_id USING ERRCODE = 'check_violation';
        END IF;
        v_new := v_balance - NEW.amount;
    END IF;

    NEW.balance_after := v_new;
    UPDATE customer SET current_balance = v_new, updated_at = now() WHERE customer_id = NEW.customer_id;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_post_transaction
    BEFORE INSERT ON account_transaction
    FOR EACH ROW EXECUTE FUNCTION fn_post_transaction();

-- ---------- 2. Ledger immutability ----------
CREATE OR REPLACE FUNCTION fn_ledger_immutable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'account_transaction is append-only: % is not permitted', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END $$;

CREATE TRIGGER trg_ledger_immutable
    BEFORE UPDATE OR DELETE ON account_transaction
    FOR EACH ROW EXECUTE FUNCTION fn_ledger_immutable();

-- ---------- 3. Generic audit trigger ----------
CREATE OR REPLACE FUNCTION fn_audit_row() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, record_pk, action, old_data)
        VALUES (TG_TABLE_NAME, to_jsonb(OLD) ->> TG_ARGV[0], TG_OP, to_jsonb(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, record_pk, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, to_jsonb(NEW) ->> TG_ARGV[0], TG_OP, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSE
        INSERT INTO audit_log (table_name, record_pk, action, new_data)
        VALUES (TG_TABLE_NAME, to_jsonb(NEW) ->> TG_ARGV[0], TG_OP, to_jsonb(NEW));
        RETURN NEW;
    END IF;
END $$;

CREATE TRIGGER trg_audit_benefit
    AFTER INSERT OR UPDATE OR DELETE ON benefit_application
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('benefit_id');

-- Customer: audit changes to biodata/status only (balance movements are already in the ledger)
CREATE TRIGGER trg_audit_customer_upd
    AFTER UPDATE ON customer
    FOR EACH ROW
    WHEN ((to_jsonb(OLD) - 'current_balance' - 'updated_at') IS DISTINCT FROM
          (to_jsonb(NEW) - 'current_balance' - 'updated_at'))
    EXECUTE FUNCTION fn_audit_row('customer_id');

CREATE TRIGGER trg_audit_customer_del
    AFTER DELETE ON customer
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('customer_id');

-- ---------- 4. Benefit eligibility and cap (simplified model rules) ----------
-- Model rules (academic simplification; verify against PRA 2014 / PenCom guidelines before real use):
--   25% withdrawal & equity-mortgage : customer not deceased; amount <= 25% of balance
--   lump sum                         : customer RETIRED; amount <= balance
--   voluntary withdrawal             : customer not deceased; amount <= balance
--   death benefit                    : customer DECEASED; amount <= balance
--   only one 25% withdrawal per customer (model rule)
CREATE OR REPLACE FUNCTION fn_benefit_cap(p_customer_id BIGINT, p_type benefit_type)
RETURNS NUMERIC LANGUAGE plpgsql AS $$
DECLARE c customer%ROWTYPE;
BEGIN
    SELECT * INTO c FROM customer WHERE customer_id = p_customer_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Customer % does not exist', p_customer_id; END IF;

    IF p_type = 'LUMP_SUM_WITHDRAWAL' THEN
        IF c.status <> 'RETIRED' THEN RAISE EXCEPTION 'Lump sum requires RETIRED status (customer % is %)', c.customer_id, c.status; END IF;
        RETURN c.current_balance;
    ELSIF p_type = 'DEATH_BENEFIT_WITHDRAWAL' THEN
        IF c.status <> 'DECEASED' THEN RAISE EXCEPTION 'Death benefit requires DECEASED status (customer % is %)', c.customer_id, c.status; END IF;
        RETURN c.current_balance;
    ELSIF p_type IN ('25_PERCENT_WITHDRAWAL', 'EQUITY_MORTGAGE_WITHDRAWAL') THEN
        IF c.status = 'DECEASED' THEN RAISE EXCEPTION 'Customer % is deceased', c.customer_id; END IF;
        RETURN round(c.current_balance * 0.25, 2);
    ELSE
        IF c.status = 'DECEASED' THEN RAISE EXCEPTION 'Customer % is deceased', c.customer_id; END IF;
        RETURN c.current_balance;
    END IF;
END $$;

-- ---------- 5. Benefit workflow: submit -> approve/reject -> pay ----------
CREATE OR REPLACE FUNCTION submit_benefit_application(
    p_customer_id BIGINT, p_type benefit_type, p_amount NUMERIC, p_doc_ref VARCHAR DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = ap, pg_temp AS $$
DECLARE v_cap NUMERIC; v_id BIGINT;
BEGIN
    v_cap := fn_benefit_cap(p_customer_id, p_type);
    IF p_amount > v_cap THEN
        RAISE EXCEPTION 'Requested % exceeds the permitted maximum % for %', p_amount, v_cap, p_type
            USING ERRCODE = 'check_violation';
    END IF;
    INSERT INTO benefit_application (customer_id, benefit_type, amount_requested, supporting_document_ref)
    VALUES (p_customer_id, p_type, p_amount, p_doc_ref) RETURNING benefit_id INTO v_id;
    RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION approve_benefit(p_benefit_id BIGINT, p_approver TEXT, p_amount NUMERIC DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = ap, pg_temp AS $$
DECLARE b benefit_application%ROWTYPE; v_cap NUMERIC; v_amt NUMERIC;
BEGIN
    SELECT * INTO b FROM benefit_application WHERE benefit_id = p_benefit_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Benefit application % not found', p_benefit_id; END IF;
    IF b.status <> 'PENDING' THEN RAISE EXCEPTION 'Application % is already %', b.benefit_id, b.status; END IF;

    PERFORM 1 FROM customer WHERE customer_id = b.customer_id FOR UPDATE;   -- lock before checking balance

    v_cap := fn_benefit_cap(b.customer_id, b.benefit_type);
    v_amt := COALESCE(p_amount, b.amount_requested);
    IF v_amt > v_cap THEN
        RAISE EXCEPTION 'Approved amount % exceeds the permitted maximum % for %', v_amt, v_cap, b.benefit_type
            USING ERRCODE = 'check_violation';
    END IF;

    IF b.benefit_type = '25_PERCENT_WITHDRAWAL' AND EXISTS (
        SELECT 1 FROM benefit_application
         WHERE customer_id = b.customer_id AND benefit_type = b.benefit_type
           AND status IN ('APPROVED', 'PAID') AND benefit_id <> b.benefit_id) THEN
        RAISE EXCEPTION 'Customer % has already received a 25%% withdrawal', b.customer_id
            USING ERRCODE = 'check_violation';
    END IF;

    UPDATE benefit_application
       SET status = 'APPROVED', amount_approved = v_amt, decision_date = CURRENT_DATE, decided_by = p_approver
     WHERE benefit_id = p_benefit_id;
END $$;

CREATE OR REPLACE FUNCTION reject_benefit(p_benefit_id BIGINT, p_approver TEXT, p_reason TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = ap, pg_temp AS $$
BEGIN
    UPDATE benefit_application
       SET status = 'REJECTED', rejection_reason = p_reason, decision_date = CURRENT_DATE, decided_by = p_approver
     WHERE benefit_id = p_benefit_id AND status = 'PENDING';
    IF NOT FOUND THEN RAISE EXCEPTION 'Application % not found or not PENDING', p_benefit_id; END IF;
END $$;

CREATE OR REPLACE FUNCTION pay_benefit(p_benefit_id BIGINT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = ap, pg_temp AS $$
DECLARE b benefit_application%ROWTYPE; v_txn BIGINT;
BEGIN
    SELECT * INTO b FROM benefit_application WHERE benefit_id = p_benefit_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Benefit application % not found', p_benefit_id; END IF;
    IF b.status <> 'APPROVED' THEN RAISE EXCEPTION 'Application % must be APPROVED before payment (is %)', b.benefit_id, b.status; END IF;

    INSERT INTO account_transaction (customer_id, txn_type, amount, txn_date, benefit_id, reference)
    VALUES (b.customer_id, 'PAYMENT', b.amount_approved, CURRENT_DATE, b.benefit_id,
            'PAY-' || lpad(b.benefit_id::text, 10, '0'))
    RETURNING txn_id INTO v_txn;                     -- trigger posts balance and rejects overdrafts

    UPDATE benefit_application SET status = 'PAID' WHERE benefit_id = p_benefit_id;
    RETURN v_txn;
END $$;
