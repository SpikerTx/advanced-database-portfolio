-- Q6: work queue - oldest pending benefit applications from the last 30 days with customer and employer
SELECT ba.benefit_id, ba.benefit_type, ba.application_date, ba.amount_requested, c.surname, c.first_name, e.employer_name
FROM benefit_application ba
JOIN customer c USING (customer_id)
JOIN employer e USING (employer_id)
WHERE ba.status = 'PENDING' AND ba.application_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY ba.application_date
LIMIT 50;
