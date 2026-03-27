-- Network Fee Benchmarking vs Peer Processors
-- Straive Strategic Analytics | Processor Interchange Optimisation

WITH client_fees AS (
    SELECT
        card_brand,
        fee_type,
        SUM(fee_amount)                                       AS total_fees,
        SUM(t.amount)                                         AS total_volume,
        COUNT(t.txn_id)                                       AS total_txns,
        SUM(fee_amount) / NULLIF(SUM(t.amount), 0) * 10000   AS fee_bps,
        SUM(fee_amount) / NULLIF(COUNT(t.txn_id), 0)         AS fee_per_txn
    FROM fact_network_fees f
    JOIN fact_transactions t USING (txn_id)
    WHERE f.fee_date BETWEEN :start_date AND :end_date
    GROUP BY 1, 2
),

peer_benchmarks AS (
    -- Network-published and anonymised peer data
    SELECT card_brand, fee_type,
        AVG(fee_bps) AS peer_avg_bps,
        MIN(fee_bps) AS peer_min_bps,
        MAX(fee_bps) AS peer_max_bps
    FROM dim_peer_fee_benchmarks
    WHERE benchmark_period = DATE_TRUNC('quarter', :start_date)
    GROUP BY 1, 2
)

SELECT
    cf.card_brand,
    cf.fee_type,
    cf.total_fees,
    cf.total_volume,
    cf.fee_bps                                                AS client_fee_bps,
    pb.peer_avg_bps,
    pb.peer_min_bps,
    cf.fee_bps - pb.peer_avg_bps                             AS vs_peer_avg_bps,
    CASE
        WHEN cf.fee_bps > pb.peer_avg_bps * 1.1 THEN 'Above Benchmark — Negotiate'
        WHEN cf.fee_bps < pb.peer_avg_bps * 0.9 THEN 'Below Benchmark — Advantage'
        ELSE 'At Benchmark'
    END                                                       AS benchmark_status,
    (cf.fee_bps - pb.peer_min_bps) / 10000 * cf.total_volume AS negotiation_opportunity
FROM client_fees cf
LEFT JOIN peer_benchmarks pb
    ON cf.card_brand = pb.card_brand AND cf.fee_type = pb.fee_type
ORDER BY negotiation_opportunity DESC NULLS LAST
