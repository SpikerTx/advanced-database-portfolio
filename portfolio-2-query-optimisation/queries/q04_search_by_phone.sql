-- Q4: call-centre lookup by phone number
SELECT customer_id, surname, first_name, status, current_balance
FROM customer
WHERE phone_number = :phone;
