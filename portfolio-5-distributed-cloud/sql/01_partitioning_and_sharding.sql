-- =====================================================================
-- Portfolio 5 | Horizontal partitioning of the ledger (single-node simulation of sharding)
--  A) RANGE partitioning by txn_date  -> archive/retention and partition pruning for date-bounded reports
--  B) HASH partitioning by customer_id -> models shard placement (each partition = one future shard node)
-- Source data: ap.account_transaction (built by Portfolio 1)
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;
SET search_path = ap, public;
\pset pager off

-- reporting window: the calendar month two months ago (always inside the generated data)
SELECT (date_trunc('month', CURRENT_DATE) - interval '2 months')::date AS d1,
       (date_trunc('month', CURRENT_DATE) - interval '1 month')::date  AS d2 \gset

DROP SCHEMA IF EXISTS ap_dist CASCADE;
CREATE SCHEMA ap_dist;

-- ---------- A) RANGE partitions by year ----------
CREATE TABLE ap_dist.txn_range (
    txn_id        BIGINT        NOT NULL,
    customer_id   BIGINT        NOT NULL,
    txn_type      ap.txn_type   NOT NULL,
    amount        NUMERIC(18,2) NOT NULL,
    txn_date      DATE          NOT NULL,
    balance_after NUMERIC(18,2) NOT NULL,
    PRIMARY KEY (txn_id, txn_date)               -- the partition key must be part of every unique key
) PARTITION BY RANGE (txn_date);

DO $$
DECLARE y INT; y_min INT; y_max INT;
BEGIN
    SELECT EXTRACT(YEAR FROM min(txn_date)), EXTRACT(YEAR FROM max(txn_date)) + 1 INTO y_min, y_max FROM ap.account_transaction;
    FOR y IN y_min .. y_max LOOP
        EXECUTE format('CREATE TABLE ap_dist.txn_range_%s PARTITION OF ap_dist.txn_range FOR VALUES FROM (%L) TO (%L)',
                       y, make_date(y, 1, 1), make_date(y + 1, 1, 1));
    END LOOP;
END $$;
CREATE TABLE ap_dist.txn_range_default PARTITION OF ap_dist.txn_range DEFAULT;

INSERT INTO ap_dist.txn_range
SELECT txn_id, customer_id, txn_type, amount, txn_date, balance_after FROM ap.account_transaction;

\echo '--- Rows per range partition'
SELECT tableoid::regclass AS partition, count(*) AS row_count FROM ap_dist.txn_range GROUP BY 1 ORDER BY 1;

\echo '--- Partition pruning: a one-month report touches ONE partition only'
EXPLAIN (COSTS OFF)
SELECT sum(amount) FROM ap_dist.txn_range WHERE txn_date >= :'d1' AND txn_date < :'d2';

-- ---------- B) HASH partitions by customer (shard simulation) ----------
CREATE TABLE ap_dist.txn_shard (
    txn_id        BIGINT        NOT NULL,
    customer_id   BIGINT        NOT NULL,
    txn_type      ap.txn_type   NOT NULL,
    amount        NUMERIC(18,2) NOT NULL,
    txn_date      DATE          NOT NULL,
    balance_after NUMERIC(18,2) NOT NULL,
    PRIMARY KEY (customer_id, txn_id)
) PARTITION BY HASH (customer_id);

CREATE TABLE ap_dist.txn_shard_0 PARTITION OF ap_dist.txn_shard FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE ap_dist.txn_shard_1 PARTITION OF ap_dist.txn_shard FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE ap_dist.txn_shard_2 PARTITION OF ap_dist.txn_shard FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE ap_dist.txn_shard_3 PARTITION OF ap_dist.txn_shard FOR VALUES WITH (MODULUS 4, REMAINDER 3);

INSERT INTO ap_dist.txn_shard
SELECT txn_id, customer_id, txn_type, amount, txn_date, balance_after FROM ap.account_transaction;

\echo '--- Shard balance: rows per "shard" (should be roughly even)'
SELECT tableoid::regclass AS shard, count(*) AS row_count, count(DISTINCT customer_id) AS customers
FROM ap_dist.txn_shard GROUP BY 1 ORDER BY 1;

\echo '--- Single-customer statement is routed to exactly ONE shard (shard-key lookup)'
EXPLAIN (COSTS OFF)
SELECT * FROM ap_dist.txn_shard WHERE customer_id = 1234;

\echo '--- Cross-shard query (no shard key): must visit ALL shards - the cost of sharding'
EXPLAIN (COSTS OFF)
SELECT txn_type, sum(amount) FROM ap_dist.txn_shard WHERE txn_date >= :'d1' GROUP BY txn_type;

ANALYZE ap_dist.txn_range; ANALYZE ap_dist.txn_shard;
