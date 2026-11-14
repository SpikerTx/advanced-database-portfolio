-- Q2: monthly remittance schedule for one employer over the last 12 months
SELECT e.employer_name, date_trunc('month', t.txn_date)::date AS month, SUM(t.amount) AS total_contributions, COUNT(*) AS postings
FROM account_transaction t
JOIN employer e USING (employer_id)
WHERE t.employer_id = :emp AND t.txn_type = 'CONTRIBUTION' AND t.txn_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY e.employer_name, date_trunc('month', t.txn_date)
ORDER BY month;
