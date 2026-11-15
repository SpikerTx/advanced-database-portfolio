-- Sample JSONB queries (run: psql -f 02_jsonb_queries.sql)
SET search_path = ap, public;
\pset pager off

\echo '--- 1. One customer as a JSON document'
SELECT jsonb_pretty(doc) FROM v_customer_document WHERE customer_id = 1;

\echo '--- 2. Containment (@>) uses the GIN index: equity-mortgage applications financed by one lender'
SELECT ba.benefit_id, ba.status, ba.amount_requested, bd.details ->> 'lender' AS lender
FROM benefit_application ba JOIN benefit_details bd USING (benefit_id)
WHERE bd.details @> '{"lender": "Federal Mortgage Bank"}' AND ba.status = 'PENDING'
ORDER BY ba.benefit_id LIMIT 5;

\echo '--- 3. Execution plan showing the GIN index (Bitmap Index Scan)'
EXPLAIN (ANALYZE, COSTS OFF)
SELECT count(*) FROM benefit_details WHERE details @> '{"propertyState": "Lagos"}';

\echo '--- 4. Path extraction + aggregation across document shapes'
SELECT details ->> 'purpose' AS purpose, count(*) FROM benefit_details
WHERE details ? 'purpose' GROUP BY 1 ORDER BY 2 DESC;

\echo '--- 5. Unnest an embedded array: death-benefit claimants and their shares'
SELECT bd.benefit_id, cl ->> 'name' AS claimant, (cl ->> 'share')::numeric AS share_percent
FROM benefit_details bd, jsonb_array_elements(bd.details -> 'claimants') cl
WHERE bd.details ? 'deathCertificateNo' ORDER BY bd.benefit_id LIMIT 6;
