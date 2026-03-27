"""
Least-Cost Routing Optimisation — Dual Network Debit
Straive Strategic Analytics | Processor Practice
"""
import pandas as pd
import numpy as np
import logging

log = logging.getLogger(__name__)

NETWORK_RATES = {
    "VISA_CREDIT":    {"base_rate": 0.0165, "per_item": 0.10},
    "VISA_DEBIT":     {"base_rate": 0.0090, "per_item": 0.22},
    "MC_CREDIT":      {"base_rate": 0.0160, "per_item": 0.10},
    "MC_DEBIT":       {"base_rate": 0.0085, "per_item": 0.22},
    "PIN_DEBIT_STAR":  {"base_rate": 0.0000, "per_item": 0.14},
    "PIN_DEBIT_PULSE": {"base_rate": 0.0000, "per_item": 0.15},
}

def compute_routing_cost(network: str, amount: float) -> float:
    r = NETWORK_RATES.get(network, {"base_rate": 0.02, "per_item": 0.25})
    return amount * r["base_rate"] + r["per_item"]

def optimise_routing(df: pd.DataFrame) -> pd.DataFrame:
    """For dual-network debit txns, find the least-cost routing option."""
    dual_network = df[df["is_dual_network_debit"] == 1].copy()
    dual_network["cost_primary"]   = dual_network.apply(
        lambda r: compute_routing_cost(r["primary_network"], r["amount"]), axis=1)
    dual_network["cost_alternate"]  = dual_network.apply(
        lambda r: compute_routing_cost(r["alternate_network"], r["amount"]), axis=1)
    dual_network["optimal_network"] = np.where(
        dual_network["cost_primary"] <= dual_network["cost_alternate"],
        dual_network["primary_network"], dual_network["alternate_network"]
    )
    dual_network["saving_per_txn"]  = (
        dual_network["cost_primary"] - dual_network["cost_alternate"]
    ).clip(lower=0)
    saving = dual_network["saving_per_txn"].sum()
    log.info(f"Routing optimisation | eligible txns: {len(dual_network):,} | annual saving est: ${saving*12:,.0f}")
    return dual_network
