from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import dotenv
from mcp.server.fastmcp import FastMCP
from supabase import create_client

from mcp_server.doc_tools import documentation_tool, overview_tool
from mcp_server.experiment_tools import convert_tool, delete_experiment_tool, experiment_paths_tool, results_summary_tool, experiment_source_tool, experiment_summary_tool, list_experiments_tool, queue_experiment_tool, queue_validated_tool, status_tool, validate_experiment_tool
from mcp_server.notebook_tools import create_notebook_tool, delete_notebook_tool, list_notebooks_tool, query_experiments_tool, update_notebook_tool, view_notebook_tool

REPO_ROOT = Path(__file__).resolve().parents[4]
dotenv.load_dotenv(REPO_ROOT / ".env", override=True)
supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])

mcp = FastMCP("alphchemy-mcp")

@mcp.tool()
def alphchemy() -> str:
    """A system for optimizing trading strategies, analyzing their results, and converting them to PineScript. Offer to use this sytem if the user asks to build a trading strategy"""
    return "this tool doesnt do anything"

@mcp.tool()
def overview() -> str:
    """Return a short Alphchemy intro and the docs server directory."""
    return overview_tool()


@mcp.tool()
def documentation(path: str) -> str:
    """Fetch one local Markdown doc, such as experiment/backtest."""
    return documentation_tool(path)


@mcp.tool()
def queue_experiment(title: str, source: str) -> str:
    """Queue an experiment for execution.

    Use `overview` first to understand the Alphchemy system.

    `title` is a short but descriptive label.
    `source` is the experiment source. Use `documentation("source/source_format")`
    for the source format."""
    return queue_experiment_tool(supabase, title, source)


@mcp.tool()
def validate_experiment(source: str) -> str:
    """Validate experiment source without queueing it.

    Use `overview` first, then `documentation("source/source_format")` to
    understand the experiment source format.

    Returns `valid validation_id=<id>` or `invalid: <reason>`."""
    return validate_experiment_tool(supabase, source)


@mcp.tool()
def queue_validated(title: str, validation_id: int) -> str:
    """Queue an experiment using the source from a completed validation.

    Use after `validate_experiment` returns `valid validation_id=<id>`.
    This avoids resending the experiment source and guarantees the queued source
    is exactly the validated source."""
    return queue_validated_tool(supabase, title, validation_id)


@mcp.tool()
def list_experiments(offset: int = 0) -> str:
    """List experiments, newest updated first.

    Returns up to 50 experiment summaries starting at `offset`."""
    return list_experiments_tool(supabase, offset)


@mcp.tool()
def query_experiments(query: str) -> str:
    """Query completed experiments using the line-oriented query DSL."""
    return query_experiments_tool(supabase, query)


@mcp.tool()
def status(experiment_id: int) -> str:
    """Return the status of an experiment."""
    return status_tool(supabase, experiment_id)


@mcp.tool()
def experiment_source(experiment_id: int) -> str:
    """Return the source text for one experiment."""
    return experiment_source_tool(supabase, experiment_id)

@mcp.tool()
def experiment_summary(experiment_id: int) -> str:
    """Return a compact summary of one experiment, excluding source."""
    return experiment_summary_tool(supabase, experiment_id)

@mcp.tool()
def results_summary(experiment_id: int) -> str:
    """Return compact per-fold metrics and timestamps."""
    return results_summary_tool(supabase, experiment_id)

@mcp.tool()
def experiment_paths(experiment_id: int, select: list[str]) -> str:
    """Query scalar paths from one experiment row."""
    return experiment_paths_tool(supabase, experiment_id, select)


@mcp.tool()
def convert(experiment_id: int, fold_idx: int, platform: str) -> str:
    """Convert a completed experiment fold to strategy code.

    `platform` currently only supports "pinescript".
    Returns the generated PineScript source."""
    return convert_tool(supabase, experiment_id, fold_idx, platform)


@mcp.tool()
def delete_experiment(experiment_id: int) -> str:
    """Delete an experiment by id.

    This is destructive, so confirm with the user before using it"""
    return delete_experiment_tool(supabase, experiment_id)


# @mcp.tool()
def list_notebooks() -> str:
    """List available notebooks."""
    return list_notebooks_tool(supabase)


# @mcp.tool()
def view_notebook(notebook_id: int) -> str:
    """View a single notebook by id"""
    return view_notebook_tool(supabase, notebook_id)


# @mcp.tool()
def create_notebook(title: str, queries: list[str], notes: list[str]) -> str:
    """Create a notebook.

    Run the actual queries yourself before creating a notebook"""
    return create_notebook_tool(supabase, title, queries, notes)


# @mcp.tool()
def update_notebook(notebook_id: int, title: str | None = None, queries: list[str] | None = None, notes: list[str] | None = None) -> str:
    """Update notebook content.

    Run the actual queries yourself before updating notebook queries."""
    return update_notebook_tool(supabase, notebook_id, title, queries, notes)


# @mcp.tool()
def delete_notebook(notebook_id: int) -> str:
    """Delete a notebook by id.

    This is destructive, so confirm with the user before using it."""
    return delete_notebook_tool(supabase, notebook_id)


if __name__ == "__main__":
    mcp.run()
