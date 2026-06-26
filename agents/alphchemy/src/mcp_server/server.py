from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import dotenv
from mcp.server.fastmcp import FastMCP
from supabase import create_client
from agents.prompts import EXPERIMENT_RESULTS_NOTEBOOK_DESCRIPTION, EXPERIMENT_SCHEMA, NOTEBOOK_SCHEMA_TEMPLATE
from analysis.query import Query
from analysis.format_analysis import format_query_results

REPO_ROOT = Path(__file__).resolve().parents[4]
dotenv.load_dotenv(REPO_ROOT / ".env", override=True)
supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])

mcp = FastMCP("alphchemy-mcp")

ALPHCHEMY_DESCRIPTION = """\
# Alphchemy

Alphchemy is a system where AI quantitative-researcher agents design, run, and analyze experiments to optimize algorithmic trading strategies. An agent (or a team of collaborating agents) proposes experiments, inspects their backtested results, and iterates toward strategies with the best risk-adjusted returns.

An experiment defines one concrete trading strategy and evaluates it with cross-validated backtesting. A strategy turns numerical OHLC-derived features into entry/exit signals via a boolean logic or decision network, and a genetic algorithm optimizes that network to maximize excess Sharpe ratio (strategy Sharpe minus benchmark Sharpe) on training data while validating on held-out data. Completed experiments store their per-fold backtest metrics, which agents query and aggregate to decide what to try next.

This document is the complete reference for the experiment object an agent submits, the results object produced when an experiment completes, and the JSON schema for every field. The two sections below cover, in order: the experiment and results descriptions, then the exact submission schema."""


def clear_query_results(queries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    cleared: list[dict[str, Any]] = []

    for query in queries:
        entry = dict(query)
        entry["results"] = None
        cleared.append(entry)

    return cleared


def validate_notebook_parts(queries: list[Any], notes: list[str]) -> None:
    if len(queries) != len(notes):
        raise ValueError("queries and notes must have the same length")


@mcp.tool()
def get_documentation() -> str:
    """Return the full alphchemy documentation: system overview, experiment and
    results descriptions, notebook description, and experiment/notebook JSON schemas."""
    return f"{ALPHCHEMY_DESCRIPTION}\n\n{EXPERIMENT_RESULTS_NOTEBOOK_DESCRIPTION}\n\n{EXPERIMENT_SCHEMA}\n\n{NOTEBOOK_SCHEMA_TEMPLATE}"


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
def query_experiments(query: str) -> str:
    """Query completed experiments with a SQL-style query string and return the raw
    selected values per path. The query is line-oriented (newlines and indentation
    matter). Example:

      select:
          id
          results.mean.test_results.metrics.excess_sharpe
      filters:
          results.mean.test_results.metrics.excess_sharpe > 0
      limit: 10

    `select:` lists one dot-path per indented line (required). Paths use dot notation
    over the experiment and results objects, include `id` and `title`, and support
    per-fold aggregates (len, mean, std, min, max), e.g. "experiment.strategy.stop_loss"
    or "results.mean.test_results.metrics.excess_sharpe". `filters:` lists one
    `path <op> value` per indented line (optional; all must match). Operators: >=, >,
    <=, <, == ; values are numbers, "quoted strings", or true/false. `limit: N` caps the
    number of experiments (optional, default 25, max 25). See get_documentation for the
    experiment and results schema."""
    parsed = Query(query = query)
    parsed.run(supabase)
    return format_query_results(parsed)


@mcp.tool()
def get_experiment(experiment_id: int) -> dict:
    """Return the full row for a single experiment by id: title, the raw experiment
    object, its results, and status. Use after query_experiments to inspect a match."""
    table = supabase.table("experiments")
    selected = table.select("id, title, experiment, results, status")
    rows = selected.eq("id", experiment_id).execute().data
    return rows[0]


@mcp.tool()
def list_notebooks() -> list[dict[str, Any]]:
    """List available notebooks.

    Returns one summary object per notebook, ordered by `last_edited` descending
    so recently changed notebooks appear first. Each summary contains `id`,
    `last_edited`, `title`, and `status`. Use `view_notebook` with a returned
    `id` to inspect the notebook's queries, notes, query results, and error
    message."""
    table = supabase.table("notebooks")
    selected = table.select("id, last_edited, title, status")
    ordered = selected.order("last_edited", desc = True)
    return ordered.execute().data


@mcp.tool()
def view_notebook(notebook_id: int) -> dict[str, Any]:
    """View a single notebook by id.

    `notebook_id` is the integer id from `list_notebooks` or another notebook
    result. The returned row contains `id`, `last_edited`, `title`, `queries`,
    `notes`, `status`, and `error_message`. `queries` is an ordered list of
    objects with a raw query string in `query` and optional computed values in
    `results`; `notes` is aligned by index, so `notes[i]` describes
    `queries[i]`."""
    table = supabase.table("notebooks")
    selected = table.select("id, last_edited, title, queries, notes, status, error_message")
    rows = selected.eq("id", notebook_id).limit(1).execute().data
    return rows[0]


@mcp.tool()
def create_notebook(title: str, queries: list[str], notes: list[str]) -> dict[str, Any]:
    """Create a notebook.

    `title` is a short human-readable label. `queries` is an ordered list of
    raw query strings, and `notes` is the ordered note list aligned by index
    with `queries`. Both lists are required and must have the same length. Pass
    empty lists to create an empty notebook.

    Empty notebooks are created with `status` set to `idle`. Notebooks with
    queries are created with query `results` set to null and `status` set to
    `working` so the notebook worker populates results asynchronously. The
    returned value is the full inserted notebook row."""
    validate_notebook_parts(queries, notes)

    status = "working" if len(queries) > 0 else "idle"
    payload = {
        "title": title.strip(),
        "queries": [{"query": query, "results": None} for query in queries],
        "notes": notes,
        "status": status,
        "error_message": None
    }

    table = supabase.table("notebooks")
    inserted = table.insert(payload)
    rows = inserted.execute().data
    return rows[0]


@mcp.tool()
def update_notebook(notebook_id: int, title: str | None = None, queries: list[str] | None = None, notes: list[str] | None = None) -> dict[str, Any]:
    """Update notebook content and queue query recomputation.

    `notebook_id` is the target notebook id. `title`, `queries`, and `notes`
    are optional; pass null for any field that should remain unchanged. Every
    call sets `status` to `working`, clears `error_message`, clears existing
    query `results`, and updates `last_edited` so the notebook worker refreshes
    results asynchronously.

    When replacing `queries`, pass them as raw query strings and also provide
    the full replacement `notes` list. `queries` and `notes` must have the same
    length because notebook tiles are paired by index. If `queries` is null and
    `notes` is provided, only notes are replaced and their count must match the
    existing query count. The returned value is the full updated notebook row."""
    notebook = view_notebook(notebook_id)
    values: dict[str, Any] = {
        "queries": clear_query_results(notebook["queries"]),
        "status": "working",
        "error_message": None,
        "last_edited": "now"
    }

    if title is not None:
        values["title"] = title.strip()

    if queries is not None:
        if notes is None:
            raise ValueError("notes must be provided when queries are replaced")

        validate_notebook_parts(queries, notes)
        values["queries"] = [{"query": query, "results": None} for query in queries]
        values["notes"] = notes
    elif notes is not None:
        validate_notebook_parts(notebook["queries"], notes)
        values["notes"] = notes

    table = supabase.table("notebooks")
    updated = table.update(values)
    updated.eq("id", notebook_id).execute()
    return view_notebook(notebook_id)


@mcp.tool()
def delete_notebook(notebook_id: int) -> str:
    """Delete a notebook by id.

    `notebook_id` is the integer id of the notebook to remove. This permanently
    deletes the row from the `notebooks` table, including its title, queries,
    notes, computed results, status, and error message. Returns a short
    confirmation string after the delete request completes."""
    table = supabase.table("notebooks")
    deleted = table.delete()
    deleted.eq("id", notebook_id).execute()
    return f"deleted notebook id={notebook_id}"


if __name__ == "__main__":
    mcp.run()
