-- Demo 1 | Atomicity: COMMIT, ROLLBACK, SAVEPOINT and a failed (rolled-back) overdraft
-- Re-runnable: every posting reference carries a unique run number.
\set ON_ERROR_STOP off
SET search_path = ap, public;
\pset pager off
SELECT (extract(epoch FROM clock_timestamp()))::bigint AS run \gset
SELECT customer_id AS cid, current_balance AS start_balance FROM customer
 WHERE status = 'ACTIVE' AND current_balance > 100000 ORDER BY customer_id LIMIT 1 \gset
\echo '--- Customer' :cid 'opening balance' :start_balance

\echo '--- A) COMMIT: post a voluntary contribution of 50,000'
BEGIN;
INSERT INTO account_transaction (customer_id, txn_type, contribution_source, amount, reference)
VALUES (:cid, 'CONTRIBUTION', 'VOLUNTARY', 50000, 'DEMO-C-' || :cid || '-' || :run);
SELECT current_balance FROM customer WHERE customer_id = :cid;
COMMIT;

\echo '--- B) ROLLBACK: post 75,000 then change our mind -> balance unchanged'
BEGIN;
INSERT INTO account_transaction (customer_id, txn_type, contribution_source, amount, reference)
VALUES (:cid, 'CONTRIBUTION', 'VOLUNTARY', 75000, 'DEMO-R-' || :cid || '-' || :run);
SELECT current_balance AS balance_inside_txn FROM customer WHERE customer_id = :cid;
ROLLBACK;
SELECT current_balance AS balance_after_rollback FROM customer WHERE customer_id = :cid;

\echo '--- C) SAVEPOINT: first posting kept, second (overdraft) undone, whole unit still commits'
BEGIN;
INSERT INTO account_transaction (customer_id, txn_type, contribution_source, amount, reference)
VALUES (:cid, 'CONTRIBUTION', 'VOLUNTARY', 10000, 'DEMO-S1-' || :cid || '-' || :run);
SAVEPOINT before_withdrawal;
INSERT INTO account_transaction (customer_id, txn_type, amount, benefit_id, reference)
SELECT :cid, 'PAYMENT', 999999999, benefit_id, 'DEMO-S2-' || :cid || '-' || :run FROM benefit_application LIMIT 1;
\echo '(overdraft error above is expected)'
ROLLBACK TO SAVEPOINT before_withdrawal;
SELECT current_balance AS balance_after_partial_rollback FROM customer WHERE customer_id = :cid;
COMMIT;

\echo '--- D) Atomic benefit workflow: submit -> approve -> pay inside ONE transaction'
BEGIN;
SELECT submit_benefit_application(:cid, 'VOLUNTARY_WITHDRAWAL', 20000, 'DEMO-DOC') AS benefit_id \gset
SELECT approve_benefit(:benefit_id, 'demo.officer');
SELECT pay_benefit(:benefit_id) AS payment_txn_id;
SELECT status, amount_approved FROM benefit_application WHERE benefit_id = :benefit_id;
COMMIT;

\echo '--- E) Constraint failure aborts the whole transaction (negative balance impossible)'
BEGIN;
SELECT submit_benefit_application(:cid, 'VOLUNTARY_WITHDRAWAL', 999999999999, 'TOO-BIG');
\echo '(error above is expected; the transaction is now in aborted state)'
COMMIT;   -- an aborted transaction can only ROLLBACK; COMMIT is reported as ROLLBACK

\echo '--- Final ledger tail for the customer'
SELECT txn_id, txn_type, contribution_source, amount, balance_after
FROM account_transaction WHERE customer_id = :cid ORDER BY txn_id DESC LIMIT 5;
SELECT current_balance AS final_balance FROM customer WHERE customer_id = :cid;
