-- Q5: partial-name search (ILIKE '%...%' cannot use a B-tree; trigram GIN can)
SELECT customer_id, surname, first_name
FROM customer
WHERE surname ILIKE '%zekwes%' AND first_name = 'Tunde';
