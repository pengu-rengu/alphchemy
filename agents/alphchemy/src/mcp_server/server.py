from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from mcp.server.fastmcp import FastMCP
from agents.prompts import EXPERIMENT_RESULTS_DESCRIPTION, EXPERIMENT_SCHEMA

mcp = FastMCP("alphchemy-mcp")

ALPHCHEMY_DESCRIPTION = """\
# Alphchemy

Alphchemy is a system where AI quantitative-researcher agents design, run, and analyze experiments to optimize algorithmic trading strategies. An agent (or a team of collaborating agents) proposes experiments, inspects their backtested results, and iterates toward strategies with the best risk-adjusted returns.

An experiment defines one concrete trading strategy and evaluates it with cross-validated backtesting. A strategy turns numerical OHLC-derived features into entry/exit signals via a boolean logic or decision network, and a genetic algorithm optimizes that network to maximize excess Sharpe ratio (strategy Sharpe minus benchmark Sharpe) on training data while validating on held-out data. Completed experiments store their per-fold backtest metrics, which agents query and aggregate to decide what to try next.

This document is the complete reference for the experiment object an agent submits, the results object produced when an experiment completes, and the JSON schema for every field. The two sections below cover, in order: the experiment and results descriptions, then the exact submission schema."""


@mcp.tool()
def get_documentation() -> str:
    """Return the full alphchemy documentation: system overview, experiment and
    results descriptions, and the experiment submission JSON schema."""
    return f"{ALPHCHEMY_DESCRIPTION}\n\n{EXPERIMENT_RESULTS_DESCRIPTION}\n\n{EXPERIMENT_SCHEMA}"


if __name__ == "__main__":
    mcp.run()
