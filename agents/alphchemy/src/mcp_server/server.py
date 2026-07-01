from __future__ import annotations

import os
import sys
import time
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import dotenv
from mcp.server.fastmcp import FastMCP
from supabase import create_client
from agents.prompts import EXPERIMENT_RESULTS_NOTEBOOK_DESCRIPTION, EXPERIMENT_SCHEMA
from analysis.query import Query
from analysis.format_analysis import format_query_results

REPO_ROOT = Path(__file__).resolve().parents[4]
dotenv.load_dotenv(REPO_ROOT / ".env", override=True)
supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])

mcp = FastMCP("alphchemy-mcp")

VALIDATION_POLL_SEC = 1.0
VALIDATION_TIMEOUT_SEC = 60.0

ALPHCHEMY_DESCRIPTION = """\
# Alphchemy

Alphchemy is a platform for running and analyzing experiments to optimize algorithmic trading strategies.

An experiment defines a trading strategy and evaluates it with cross-validated backtesting. A strategy turns numerical OHLC-derived features into entry/exit signals via a boolean logic or decision network, and a genetic algorithm optimizes that network to maximize the configured objective metrics on training data while validating on held-out data. Completed experiments store their per-fold backtest metrics.

__IMPORTANT NOTE__:
The backtest runs on CoinGecko USD-priced OHLC for the coin chosen by the experiment's `symbol` field (default `BTC_USDT`). On the free demo tier candles are coarse (multi-hour to daily). Available symbols: BTC_USDT, ETH_USDT, SOL_USDT, BNB_USDT, XRP_USDT, ADA_USDT, DOGE_USDT, AVAX_USDT, LINK_USDT, DOT_USDT. Some coins' close prices are large (BTC roughly $40,000-$100,000), so either make qty sufficiently small or make start_balance sufficiently large

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
    results descriptions, notebook description, and experiment JSON schema."""
    return f"{ALPHCHEMY_DESCRIPTION}\n\n{EXPERIMENT_RESULTS_NOTEBOOK_DESCRIPTION}\n\n{EXPERIMENT_SCHEMA}"


@mcp.tool()
def queue_experiment(title: str, source: str) -> str:
    """Queue an experiment for execution. Inserts a row into the experiments
    table with status 'queued'; the runner parses, validates, and executes it
    later. Use `get_documentation` first to understand the Alphchemy system and
    the experiment source format before using this tool.
    `title` is a short human-readable label. `source` is the experiment authored
    as source text (see get_documentation for the source format); it is stored
    verbatim in the `source` column. Returns the new row id."""
    payload = {"title": title, "source": source, "status": "queued"}
    table = supabase.table("experiments")
    inserted = table.insert(payload)
    rows = inserted.execute().data
    return f"queued id={rows[0]['id']} title={rows[0]['title']}"


@mcp.tool()
def validate_experiment(source: str) -> str:
    """Validate experiment source text without running it. Inserts a row into the
    validation_jobs table; the runner parses and validates the source, then writes
    the outcome. Blocks until validation completes and returns the result. Use
    `get_documentation` first to understand the experiment source format.
    `source` is the experiment source text. Returns "valid", or "invalid: <reason>"."""
    payload = {"source": source, "status": "working"}
    table = supabase.table("validation_jobs")
    inserted = table.insert(payload)
    rows = inserted.execute().data
    job_id = rows[0]["id"]

    waited = 0.0
    while waited < VALIDATION_TIMEOUT_SEC:
        time.sleep(VALIDATION_POLL_SEC)
        waited += VALIDATION_POLL_SEC
        table = supabase.table("validation_jobs")
        selected = table.select("status, result_message")
        filtered = selected.eq("id", job_id)
        row = filtered.execute().data[0]
        status = row["status"]
        if status == "completed_valid":
            return "valid"
        if status == "completed_invalid":
            return f"invalid: {row['result_message']}"
        if status == "errored":
            raise RuntimeError(f"validation job errored: {row['result_message']}")

    raise TimeoutError(f"validation job id={job_id} did not complete within {VALIDATION_TIMEOUT_SEC}s")


@mcp.tool()
def list_experiments(offset: int = 0) -> list[dict[str, Any]]:
    """List experiments, newest updated first.

    Use `get_documentation` first to understand the Alphchemy system before
    using this tool.

    Returns up to 50 experiment summaries starting at `offset`.
    Each summary contains `id`, `last_edited`, `title`, and `status`. Use
    `get_experiment` with a returned `id` to inspect the full experiment and
    results."""
    if offset < 0:
        raise ValueError("offset must be >= 0")

    table = supabase.table("experiments")
    selected = table.select("id, last_edited, title, status")
    ordered = selected.order("last_edited", desc = True)
    ranged = ordered.range(offset, offset + 49)
    return ranged.execute().data


@mcp.tool()
def query_experiments(query: str) -> str:
    """Query completed experiments with a SQL-style query string and return the raw
    selected values per path. The query is line-oriented (newlines and indentation
    matter). Use `get_documentation` first to understand the Alphchemy system
    before using this tool."""
    parsed = Query(query = query)
    parsed.run(supabase)
    return format_query_results(parsed)


@mcp.tool()
def get_experiment(experiment_id: int) -> dict:
    """Return the full row for a single experiment by id: title, the experiment
    source text, its results, and status. Use `get_documentation` first to understand
    the Alphchemy system before using this tool. Use after query_experiments to
    inspect a match."""
    table = supabase.table("experiments")
    selected = table.select("id, title, source, results, status")
    filtered = selected.eq("id", experiment_id)
    rows = filtered.execute().data
    return rows[0]


@mcp.tool()
def delete_experiment(experiment_id: int) -> str:
    """Delete an experiment by id.

    Use `get_documentation` first to understand the Alphchemy system before
    using this tool.

    `experiment_id` is the integer id of the experiment to remove. This permanently deletes an experiment, including its title, experiment object, results, and status. This is a destructive tool, so get user confirmation before using it."""
    table = supabase.table("experiments")
    deleted = table.delete()
    filtered = deleted.eq("id", experiment_id)
    filtered.execute()
    return f"deleted experiment id={experiment_id}"


@mcp.tool()
def list_notebooks() -> list[dict[str, Any]]:
    """List available notebooks.

    Use `get_documentation` first to understand the Alphchemy system before
    using this tool.

    Returns one summary object per notebook, ordered by `last_edited` descending
    so recently updated notebooks appear first. Each summary contains `id`,
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

    Use `get_documentation` first to understand the Alphchemy system before
    using this tool.

    `notebook_id` is an integer id returned from `list_notebooks`. The returned row contains `id`, `last_edited`, `title`, `queries`, `notes`, `status`, and `error_message`. `queries` is an ordered list of objects with a raw query string in `query` and optional computed values in `results`; `notes` is aligned by index, so `notes[i]` describes `queries[i]`."""
    table = supabase.table("notebooks")
    selected = table.select("id, last_edited, title, queries, notes, status, error_message")
    filtered = selected.eq("id", notebook_id)
    limited = filtered.limit(1)
    rows = limited.execute().data
    return rows[0]


@mcp.tool()
def create_notebook(title: str, queries: list[str], notes: list[str]) -> str:
    """Create a notebook.

    Use `get_documentation` first to understand the Alphchemy system before using this tool.

    `title` is a short descriptive label. `queries` is an ordered list of query strings, and `notes` is the ordered note list aligned by index with `queries`. Both lists are required and must have the same length. Pass empty lists to create an empty notebook.

    Empty notebooks are created with `status` set to `idle`. Notebooks with queries are created with query `results` set to null and `status` set to `working`."""
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
    notebook_id = table.insert(payload).execute().data[0]["id"]
    return f"created notebook id={notebook_id}"


@mcp.tool()
def update_notebook(notebook_id: int, title: str | None = None, queries: list[str] | None = None, notes: list[str] | None = None) -> str:
    """Update notebook content.

    Use `get_documentation` first to understand the Alphchemy system before using this tool.

    `notebook_id` is the target notebook id. `title`, `queries`, and `notes` are optional; pass null for any field that should remain unchanged. Every call sets `status` to `working`, clears `error_message`, clears existing query `results`, and updates `last_edited`.

    When replacing `queries`, pass them as raw query strings and also provide the full replacement `notes` list. `queries` and `notes` must have the same length because notebook tiles are paired by index. If `queries` is null and `notes` is provided, only notes are replaced."""
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
    return f"updated notebook id={notebook_id}"


@mcp.tool()
def delete_notebook(notebook_id: int) -> str:
    """Delete a notebook by id.

    Use `get_documentation` first to understand the Alphchemy system before using this tool.

    `notebook_id` is the integer id of the notebook to remove. This permanently deletes the row from the `notebooks` table, including its title, queries, notes, computed results, status, and error message. This is a destructive tool, so confirm with the user before using it."""
    table = supabase.table("notebooks")
    table.delete().eq("id", notebook_id).execute()
    return f"deleted notebook id={notebook_id}"


if __name__ == "__main__":
    mcp.run()
