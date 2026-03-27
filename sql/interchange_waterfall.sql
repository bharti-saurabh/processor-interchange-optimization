-- Interchange Category Waterfall
-- Straive Strategic Analytics | Processor Interchange Optimisation

WITH txn_rates AS (
    SELECT
        t.txn_id,
        t.merchant_id,
        t.amount,
        t.card_product,
        t.mcc_code,
        t.channel,
        t.is_commercial_card,
        t.has_level2_data,
        t.has_level3_data,
        t.days_to_settlement,
        t.three_ds_authenticated,
        ir_actual.rate_pct                                   AS actual_rate,
        ir_actual.rate_category                              AS actual_category,
        ir_optimal.rate_pct                                  AS optimal_rate,
        ir_optimal.rate_category                             AS optimal_category,
        (ir_optimal.rate_pct - ir_actual.rate_pct) * t.amount AS downgrade_cost,
        (ir_optimal.rate_pct - ir_actual.rate_pct) * 10000    AS gap_bps
    FROM fact_transactions t
    JOIN dim_interchange_rates ir_actual
        ON  t.card_product = ir_actual.card_product
        AND t.mcc_code     = ir_actual.mcc_code
        AND t.rate_qualifier = ir_actual.qualifier
    JOIN dim_interchange_rates ir_optimal
        ON  t.card_product = ir_optimal.card_product
        AND t.mcc_code     = ir_optimal.mcc_code
        AND ir_optimal.qualifier = 'OPTIMAL'
    WHERE t.txn_date BETWEEN :start_date AND :end_date
      AND t.status = 'SETTLED'
)

SELECT
    actual_category,
    optimal_category,
    COUNT(*)                                                  AS txn_count,
    SUM(amount)                                               AS total_volume,
    AVG(actual_rate) * 10000                                  AS avg_actual_rate_bps,
    AVG(optimal_rate) * 10000                                 AS avg_optimal_rate_bps,
    AVG(gap_bps)                                              AS avg_gap_bps,
    SUM(downgrade_cost)                                       AS total_downgrade_cost,
    CASE WHEN actual_category != optimal_category THEN 1 ELSE 0 END AS is_downgraded
FROM txn_rates
GROUP BY 1, 2, 9
ORDER BY total_downgrade_cost DESC
