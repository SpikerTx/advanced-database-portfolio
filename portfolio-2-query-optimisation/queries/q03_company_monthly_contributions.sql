-- Q3: company-wide monthly contributions per employer (heavy aggregation over the whole ledger)
SELECT e.employer_name, date_trunc('month', t.txn_date)::date AS month, SUM(t.amount) AS total_contributions
FROM account_transaction t
JOIN employer e USING (employer_id)
WHERE t.txn_type = 'CONTRIBUTION'
GROUP BY e.employer_name, date_trunc('month', t.txn_date)
ORDER BY e.employer_name, month;
