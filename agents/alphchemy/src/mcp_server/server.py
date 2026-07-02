from __future__ import annotations

import json
import math
import os
import sys
import time
from pathlib import Path
from typing import Any
from urllib.parse import quote
from urllib.request import urlopen

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import dotenv
from mcp.server.fastmcp import FastMCP
from supabase import create_client
from analysis.path import MissingKeyError, resolve_path
from analysis.query import Query
from analysis.format_analysis import format_query_results, format_timestamp

REPO_ROOT = Path(__file__).resolve().parents[4]
dotenv.load_dotenv(REPO_ROOT / ".env", override=True)
supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])

mcp = FastMCP("alphchemy-mcp")

VALIDATION_POLL_SEC = 1.0
VALIDATION_TIMEOUT_SEC = 60.0
DOCS_SERVER_URL = os.environ.get("DOCS_SERVER_URL", "http://localhost:5050")

ALPHCHEMY_DESCRIPTION = """\
# Alphchemy

Alphchemy is a platform for running and analyzing experiments to optimize algorithmic trading strategies.

An experiment defines a trading strategy and evaluates it with cross-validated backtesting. A strategy turns numerical OHLC-derived features into entry/exit signals via a boolean logic or decision network, and a genetic algorithm optimizes that network to maximize the configured objective metrics on training data while validating on held-out data. Completed experiments store their per-fold backtest metrics.

__IMPORTANT NOTE__:
The backtest runs on CoinGecko USD-priced OHLC for the coin chosen by the experiment's `symbol` field (default `BTC_USDT`). On the free demo tier candles are coarse (multi-hour to daily). Available symbols: BTC_USDT, ETH_USDT, SOL_USDT, BNB_USDT, XRP_USDT, ADA_USDT, DOGE_USDT, AVAX_USDT, LINK_USDT, DOT_USDT. Some coins' close prices are large (BTC roughly $40,000-$100,000), so either make qty sufficiently small or make start_balance sufficiently large

Use `get_documentation(path)` to read specific Markdown docs from the docs server before queueing experiments or working with notebooks."""


def fetch_docs_server(path: str) -> str:
    base_url = DOCS_SERVER_URL.rstrip("/")
    url = f"{base_url}{path}"

    with urlopen(url) as response:
        body = response.read()

    return body.decode("utf-8")


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


def fetch_experiment_row(experiment_id: int, columns: str) -> dict[str, Any]:
    table = supabase.table("experiments")
    selected = table.select(columns)
    filtered = selected.eq("id", experiment_id)
    rows = filtered.execute().data

    if len(rows) == 0:
        raise ValueError(f"experiment id={experiment_id} not found")

    return rows[0]


def summarize_experiment_json(experiment: Any) -> dict[str, Any] | None:
    if experiment is None:
        return None

    if not isinstance(experiment, dict):
        raise ValueError("experiment must be an object")

    summary: dict[str, Any] = {}
    for key in ["symbol", "cv_folds", "fold_size", "val_size", "test_size", "start_timestamp", "end_timestamp"]:
        if key in experiment:
            summary[key] = experiment[key]

    strategy = experiment["strategy"]
    base_net = strategy["base_net"]
    feats = strategy["feats"]
    summary["strategy_type"] = base_net["type"]
    summary["feature_count"] = len(feats)
    return summary


def summarize_results_json(results: Any) -> dict[str, Any] | None:
    if results is None:
        return None

    if isinstance(results, dict):
        summary = {
            "type": "error",
            "keys": sorted(results.keys())
        }
        if "error" in results:
            summary["error"] = results["error"]
        if "is_internal" in results:
            summary["is_internal"] = results["is_internal"]
        return summary

    if isinstance(results, list):
        return {
            "type": "folds",
            "fold_count": len(results)
        }

    raise ValueError("results must be an object, array, or null")


def summarize_backtest_results(results: Any) -> dict[str, Any]:
    if not isinstance(results, dict):
        raise ValueError("backtest results must be an object")

    return {
        "is_invalid": results["is_invalid"],
        "metrics": results["metrics"]
    }


def summarize_fold_results(fold_idx: int, fold: Any) -> dict[str, Any]:
    if not isinstance(fold, dict):
        raise ValueError("fold results must be an object")

    opt_results = fold["opt_results"]
    return {
        "fold_idx": fold_idx,
        "start_timestamp": fold["start_timestamp"],
        "end_timestamp": fold["end_timestamp"],
        "train_start_timestamp": fold["train_start_timestamp"],
        "train_end_timestamp": fold["train_end_timestamp"],
        "val_start_timestamp": fold["val_start_timestamp"],
        "val_end_timestamp": fold["val_end_timestamp"],
        "test_start_timestamp": fold["test_start_timestamp"],
        "test_end_timestamp": fold["test_end_timestamp"],
        "opt_results": {
            "iters": opt_results["iters"]
        },
        "train_results": summarize_backtest_results(fold["train_results"]),
        "val_results": summarize_backtest_results(fold["val_results"]),
        "test_results": summarize_backtest_results(fold["test_results"])
    }


def format_experiment_path_results(results: list[dict[str, Any]]) -> str:
    lines = [f"[QUERY] {len(results)} path(s)"]

    for result in results:
        lines.append("")
        lines.append(f"[RESULTS] {result['path']}")
        if result["skipped"] == 0:
            formatted = format_timestamp(result["value"])
            lines.append(f"{formatted} ({result['id']})")
        else:
            lines.append("—")

        lines.append(f"skipped: {result['skipped']}")
        if "reason" in result:
            lines.append(f"reason: {result['reason']}")

    return "\n".join(lines) + "\n\n"


@mcp.tool()
def get_overview() -> str:
    """Return a short Alphchemy intro and the docs server directory."""
    return ALPHCHEMY_DESCRIPTION
    directory_text = fetch_docs_server("/directory")
    doc_paths = json.loads(directory_text)
    doc_lines = [f"- `{doc_path}`" for doc_path in doc_paths]
    directory = "\n".join(doc_lines)
    return f"{ALPHCHEMY_DESCRIPTION}\n\n## Docs directory\n\n{directory}"


@mcp.tool()
def get_documentation(path: str) -> str:
    """Fetch one Markdown doc from the docs server, such as experiment/backtest.md."""
    quoted_path = quote(path, safe="/")
    return "Documentation is currently unavailable"
    #return fetch_docs_server(f"/docs/{quoted_path}")


@mcp.tool()
def queue_experiment(title: str, source: str) -> str:
    """Queue an experiment for execution.

    If you haven't already, use `get_overview` first to understand the Alphchemy system.

    `title` is a short but descriptive label.
    `source` is the experiment source (use `get_documentation("source/source_format.md")` for
    the source format)
    
    Returns ID if queued experiment"""
    payload = {"title": title, "source": source, "status": "queued"}
    table = supabase.table("experiments")
    inserted = table.insert(payload)
    rows = inserted.execute().data
    return f"queued id={rows[0]['id']} title={rows[0]['title']}"


@mcp.tool()
def validate_experiment(source: str) -> str:
    """Validate experiment source without queueing it. 
    Use `get_overview`
    first, then `get_documentation("source/source_format.md")` to understand
    the experiment source format.
    `source` is the experiment source text. Returns "valid validation_job_id=<id>", or "invalid: <reason>"."""
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
            return f"valid validation_job_id={job_id}"
        if status == "completed_invalid":
            return f"invalid: {row['result_message']}"
        if status == "errored":
            raise RuntimeError(f"validation job errored: {row['result_message']}")

    raise TimeoutError(f"validation job id={job_id} did not complete within {VALIDATION_TIMEOUT_SEC}s")


@mcp.tool()
def queue_validated_experiment(title: str, validation_job_id: int) -> str:
    """Queue an experiment using the exact source from a completed valid validation job.

    Use after `validate_experiment` returns `valid validation_job_id=<id>`.
    This avoids resending the experiment source and guarantees the queued source
    is exactly the validated source."""
    table = supabase.table("validation_jobs")
    selected = table.select("source, status, result_message")
    filtered = selected.eq("id", validation_job_id)
    rows = filtered.execute().data

    if len(rows) == 0:
        raise ValueError(f"validation job id={validation_job_id} not found")

    validation_job = rows[0]
    status = validation_job["status"]
    if status != "completed_valid":
        raise ValueError(f"validation job id={validation_job_id} is {status}: {validation_job['result_message']}")

    payload = {
        "title": title,
        "source": validation_job["source"],
        "status": "queued"
    }
    table = supabase.table("experiments")
    inserted = table.insert(payload)
    rows = inserted.execute().data
    return f"queued id={rows[0]['id']} title={rows[0]['title']}"


@mcp.tool()
def list_experiments(offset: int = 0) -> list[dict[str, Any]]:
    """List experiments, newest updated first.

    Use `get_overview` first to understand the Alphchemy system before
    using this tool.

    Returns up to 50 experiment summaries starting at `offset`.
    Each summary contains `id`, `last_edited`, `title`, and `status`. Use
    `get_experiment_summary`, `get_experiment_results_summary`,
    `get_experiment_source`, or `get_experiment_paths` to inspect a returned id."""
    if offset < 0:
        raise ValueError("offset must be >= 0")

    table = supabase.table("experiments")
    selected = table.select("id, last_edited, title, status")
    ordered = selected.order("last_edited", desc = True)
    ranged = ordered.range(offset, offset + 49)
    return ranged.execute().data


@mcp.tool()
def query_experiments(query: str) -> str:
    """Query completed experiments using a
    selected values per path. The query is line-oriented (newlines and indentation
    matter). Use `get_overview` first to understand the Alphchemy system
    before using this tool."""
    parsed = Query(query = query)
    parsed.run(supabase)
    return format_query_results(parsed)


@mcp.tool()
def get_status(experiment_id: int) -> str:
    """Get status of an experiment."""
    row = fetch_experiment_row(experiment_id, "id, status")
    return f"status for experiment id={experiment_id}: {row['status']}"


@mcp.tool()
def get_experiment_source(experiment_id: int) -> str:
    """Return only the source text for one experiment."""
    row = fetch_experiment_row(experiment_id, "source")
    return row["source"]


@mcp.tool()
def get_experiment_summary(experiment_id: int) -> dict[str, Any]:
    """Return a compact summary of the experiment row's raw JSON fields, excluding source."""
    row = fetch_experiment_row(experiment_id, "id, title, status, experiment, results")
    return {
        "id": row["id"],
        "title": row["title"],
        "status": row["status"],
        "experiment": summarize_experiment_json(row["experiment"]),
        "results": summarize_results_json(row["results"])
    }


@mcp.tool()
def get_experiment_results_summary(experiment_id: int) -> dict[str, Any]:
    """Return compact per-fold metrics and timestamps, omitting bulky networks,
    sequences, improvements, and equity curves."""
    row = fetch_experiment_row(experiment_id, "id, title, status, results")
    results = row["results"]
    response: dict[str, Any] = {
        "id": row["id"],
        "title": row["title"],
        "status": row["status"]
    }

    if isinstance(results, dict):
        response["results"] = summarize_results_json(results)
        return response

    if results is None:
        response["results"] = None
        return response

    if not isinstance(results, list):
        raise ValueError("results must be an object, array, or null")

    folds: list[dict[str, Any]] = []
    for fold_idx, fold in enumerate(results):
        fold_summary = summarize_fold_results(fold_idx, fold)
        folds.append(fold_summary)

    response["results"] = {
        "type": "folds",
        "folds": folds
    }
    return response


@mcp.tool()
def get_experiment_paths(experiment_id: int, select: list[str]) -> str:
    """Query scalar paths from one experiment row.

    Uses the same dot-path and aggregate syntax as `query_experiments`.
    Read `get_documentation("notebooks.md")` for query syntax and examples."""
    row = fetch_experiment_row(experiment_id, "id, last_edited, title, status, experiment, results")
    results: list[dict[str, Any]] = []

    for path in select:
        if path == "source" or path.startswith("source."):
            results.append({
                "path": path,
                "skipped": 1,
                "reason": "source is not available through get_experiment_paths; use get_experiment_source"
            })
            continue

        try:
            value = resolve_path(row, path)
            if isinstance(value, float) and not math.isfinite(value):
                results.append({
                    "path": path,
                    "skipped": 1,
                    "reason": "resolved value is not finite"
                })
                continue

            results.append({
                "path": path,
                "value": value,
                "id": experiment_id,
                "skipped": 0
            })
        except MissingKeyError as error:
            results.append({
                "path": path,
                "skipped": 1,
                "reason": str(error)
            })
        except Exception as error:
            results.append({
                "path": path,
                "skipped": 1,
                "reason": str(error)
            })

    return format_experiment_path_results(results)


@mcp.tool()
def delete_experiment(experiment_id: int) -> str:
    """Delete an experiment by id.

    Use `get_overview` first to understand the Alphchemy system before
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

    Use `get_overview` first to understand the Alphchemy system before
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

    Use `get_overview` first to understand the Alphchemy system before
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

    Use `get_overview` first to understand the Alphchemy system before using this tool.

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

    Use `get_overview` first to understand the Alphchemy system before using this tool.

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

    Use `get_overview` first to understand the Alphchemy system before using this tool.

    `notebook_id` is the integer id of the notebook to remove. This permanently deletes the row from the `notebooks` table, including its title, queries, notes, computed results, status, and error message. This is a destructive tool, so confirm with the user before using it."""
    table = supabase.table("notebooks")
    table.delete().eq("id", notebook_id).execute()
    return f"deleted notebook id={notebook_id}"


if __name__ == "__main__":
    mcp.run()
