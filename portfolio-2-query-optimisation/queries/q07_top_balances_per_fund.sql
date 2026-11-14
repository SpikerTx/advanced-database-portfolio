-- Q7: top 5 balances in every fund (window function)
SELECT fund_type_id, customer_id, current_balance, rnk FROM (
  SELECT fund_type_id, customer_id, current_balance,
         ROW_NUMBER() OVER (PARTITION BY fund_type_id ORDER BY current_balance DESC) AS rnk
  FROM customer WHERE status = 'ACTIVE'
) x WHERE rnk <= 5
ORDER BY fund_type_id, rnk;
