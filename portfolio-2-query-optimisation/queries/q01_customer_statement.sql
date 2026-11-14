-- Q1: 12-month statement for one customer (OLTP point query on the largest table)
SELECT txn_date, txn_type, contribution_source, amount, balance_after
FROM account_transaction
WHERE customer_id = :cid AND txn_date >= CURRENT_DATE - INTERVAL '12 months'
ORDER BY txn_date DESC, txn_id DESC;
