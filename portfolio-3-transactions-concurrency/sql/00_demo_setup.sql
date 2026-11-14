-- Scratch objects for the concurrency demonstrations (kept out of the production schema)
\set ON_ERROR_STOP on
SET client_min_messages = warning;
DROP SCHEMA IF EXISTS ap_demo CASCADE;
CREATE SCHEMA ap_demo;
CREATE TABLE ap_demo.account (id INT PRIMARY KEY, balance NUMERIC(18,2) NOT NULL CHECK (balance >= 0));
INSERT INTO ap_demo.account VALUES (1, 1000000), (2, 1000000);
-- Write-skew demo: at most ONE open 25% application per customer (rule enforced by application code only)
CREATE TABLE ap_demo.application (id SERIAL PRIMARY KEY, customer_id INT NOT NULL, status TEXT NOT NULL);
