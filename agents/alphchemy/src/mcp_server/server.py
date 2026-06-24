from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import dotenv
from mcp.server.fastmcp import FastMCP
from supabase import create_client
from agents.prompts import EXPERIMENT_RESULTS_DESCRIPTION, EXPERIMENT_SCHEMA
from analysis.query import SearchQuery, SelectQuery
from analysis.format_analysis import format_search_results, format_select_results, format_skipped

REPO_ROOT = Path(__file__).resolve().parents[4]
dotenv.load_dotenv(REPO_ROOT / ".env", override=True)
supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])

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


@mcp.tool()
def queue_experiment(title: str, experiment: dict) -> str:
    """Queue an experiment for execution. Inserts a row into the experiments
    table with status 'queued'; the runner validates and executes it later.
    `title` is a short human-readable label. `experiment` is the raw experiment
    object (see get_documentation for the schema). Returns the new row id."""
    payload = {"title": title, "experiment": experiment, "status": "queued"}
    table = supabase.table("experiments")
    inserted = table.insert(payload)
    response = inserted.execute()
    rows = response.data
    row = rows[0]
    return f"queued id={row['id']} title={row['title']}"


@mcp.tool()
def search_experiments(filters: list[dict]) -> str:
    """Search completed experiments and return the ids of matches. `filters` is a
    list of filter objects, each one of:
      {"type": "numeric", "path": "<dot.path>", "gte"/"lte"/"eq": <number>}
      {"type": "string", "path": "<dot.path>", "eq": "<text>"}
      {"type": "bool", "path": "<dot.path>", "eq": true/false}
    A filter may set any combination of gte/lte/eq. An experiment matches when it
    satisfies every filter. Paths use dot notation over the experiment and results
    objects and support per-fold aggregates (len, mean, std, min, max), e.g.
    "experiment.strategy.stop_loss" or "results.mean.test_results.metrics.excess_sharpe".
    An empty `filters` list matches all completed experiments. See get_documentation
    for the experiment and results schema."""
    query = SearchQuery(filters = filters)
    query.run(supabase)
    return f"{format_search_results(query)}{format_skipped(query.skipped)}"


@mcp.tool()
def analyze_experiments(select: list[str], filters: list[dict]) -> str:
    """Summarize numeric metrics across completed experiments matching `filters`.
    `select` is a list of numeric dot-paths (same path rules and aggregates as
    search_experiments). For each path this returns min, q1, median, q3 and max
    across the matching experiments. `filters` has the same shape as in
    search_experiments. See get_documentation for the experiment and results schema."""
    query = SelectQuery(select = select, filters = filters)
    query.run(supabase)
    return f"{format_select_results(query)}{format_skipped(query.skipped)}"


@mcp.tool()
def get_experiment(experiment_id: int) -> dict:
    """Return the full row for a single experiment by id: title, the raw experiment
    object, its results, and status. Use after search_experiments to inspect a match."""
    table = supabase.table("experiments")
    selected = table.select("id, title, experiment, results, status")
    rows = selected.eq("id", experiment_id).execute().data
    return rows[0]


if __name__ == "__main__":
    mcp.run()
