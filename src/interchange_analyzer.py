"""
Interchange Category Analyser — Downgrade Detection
Straive Strategic Analytics | Processor Practice
"""
import pandas as pd
import numpy as np
import logging

log = logging.getLogger(__name__)

DOWNGRADE_REASONS = {
    "missing_l2_data":     lambda r: r["is_commercial_card"] and not r["has_level2_data"],
    "missing_l3_data":     lambda r: r["is_purchasing_card"] and not r["has_level3_data"],
    "late_settlement":     lambda r: r["days_to_settlement"] > 2,
    "missing_avs":         lambda r: r["is_cnp"] and not r["avs_provided"],
    "cnp_without_3ds":     lambda r: r["is_cnp"] and not r["three_ds_authenticated"],
    "missing_auth_code":   lambda r: pd.isna(r["auth_code"]) or r["auth_code"] == "",
}

def classify_downgrade(row: pd.Series) -> list:
    return [reason for reason, check in DOWNGRADE_REASONS.items() if check(row)]

def analyse_portfolio(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["downgrade_reasons"] = df.apply(classify_downgrade, axis=1)
    df["is_downgraded"]     = df["downgrade_reasons"].apply(len) > 0
    df["rate_gap_bps"]      = (df["optimal_rate"] - df["actual_rate"]) * 10000
    df["cost_of_downgrade"] = df["amount"] * (df["optimal_rate"] - df["actual_rate"])

    by_reason = []
    for reason in DOWNGRADE_REASONS:
        mask = df["downgrade_reasons"].apply(lambda x: reason in x)
        by_reason.append({
            "downgrade_reason": reason,
            "txn_count": mask.sum(),
            "affected_volume": df.loc[mask, "amount"].sum(),
            "annual_cost_est": df.loc[mask, "cost_of_downgrade"].sum() * 12,
            "avg_rate_gap_bps": df.loc[mask, "rate_gap_bps"].mean(),
        })
    result = pd.DataFrame(by_reason).sort_values("annual_cost_est", ascending=False)
    log.info("Downgrade analysis:\n" + result.to_string(index=False))
    return result
