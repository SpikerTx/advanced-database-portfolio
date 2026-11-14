-- Sanity checks run at the end of every build. Every "violations" value must be 0.
SET search_path = ap, public;

SELECT 'customers' AS item, count(*) AS rows FROM customer
UNION ALL SELECT 'next_of_kin', count(*) FROM next_of_kin
UNION ALL SELECT 'account_transaction', count(*) FROM account_transaction
UNION ALL SELECT 'benefit_application', count(*) FROM benefit_application
UNION ALL SELECT 'audit_log', count(*) FROM audit_log
ORDER BY 1;

SELECT 'customer balance <> last ledger balance' AS check_name, count(*) AS violations
FROM customer c
JOIN (SELECT DISTINCT ON (customer_id) customer_id, balance_after
        FROM account_transaction ORDER BY customer_id, txn_id DESC) l USING (customer_id)
WHERE c.current_balance <> l.balance_after
UNION ALL
SELECT 'ledger running balance <> recomputed running sum', count(*) FROM (
  SELECT balance_after,
         SUM(CASE WHEN txn_type = 'CONTRIBUTION' THEN amount ELSE -amount END)
             OVER (PARTITION BY customer_id ORDER BY txn_id) AS running
  FROM account_transaction) x
WHERE x.running <> x.balance_after
UNION ALL
SELECT 'negative balances', count(*) FROM customer WHERE current_balance < 0
UNION ALL
SELECT 'paid benefits without a ledger payment', count(*)
FROM benefit_application ba
WHERE ba.status = 'PAID' AND NOT EXISTS (SELECT 1 FROM account_transaction t WHERE t.benefit_id = ba.benefit_id);
