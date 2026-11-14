-- Q3 (materialised): identical business question answered from the pre-aggregated view
SELECT e.employer_name, m.month, m.total_contributions
FROM mv_monthly_contributions m
JOIN employer e USING (employer_id)
ORDER BY e.employer_name, m.month;
