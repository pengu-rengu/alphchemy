from __future__ import annotations

import json
import os
import sys
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from contextvars import ContextVar
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import dotenv
import uvicorn
from fastapi import FastAPI
from mcp.server.fastmcp import FastMCP
from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Receive, Scope, Send
from supabase import Client, create_client

from mcp_server.doc_tools import documentation_tool, overview_tool
from mcp_server.experiment_tools import convert_tool, delete_experiment_tool, experiment_paths_tool, results_summary_tool, experiment_source_tool, experiment_summary_tool, list_experiments_tool, queue_experiment_tool, queue_validated_tool, status_tool, validate_experiment_tool
from mcp_server.notebook_tools import create_notebook_tool, delete_notebook_tool, list_notebooks_tool, query_experiments_tool, update_notebook_tool, view_notebook_tool

current_user_id: ContextVar[str] = ContextVar("current_user_id")


def extract_api_key(path: str) -> str:
    prefix = "/mcp/"
    if not path.startswith(prefix):
        raise PermissionError("API key is required in the MCP URL")

    api_key = path.removeprefix(prefix)
    if len(api_key) == 0 or "/" in api_key:
        raise PermissionError("API key is required in the MCP URL")

    return api_key


def find_user_id(supabase: Client, api_key: str) -> str:
    table = supabase.table("api_keys")
    selected = table.select("user_id")
    filtered = selected.eq("api_key", api_key)
    limited = filtered.limit(1)
    rows = limited.execute().data

    if len(rows) == 0:
        raise PermissionError("Invalid API key")

    return rows[0]["user_id"]


class ApiKeyMiddleware:
    def __init__(self, app: ASGIApp, supabase: Client) -> None:
        self.app = app
        self.supabase = supabase

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        try:
            api_key = extract_api_key(scope["path"])
            user_id = find_user_id(self.supabase, api_key)
        except PermissionError as error:
            message = str(error)
            response = JSONResponse({"detail": message}, status_code = 401)
            await response(scope, receive, send)
            return

        request_scope: dict[str, Any] = dict(scope)
        request_scope["path"] = "/mcp"
        token = current_user_id.set(user_id)

        try:
            await self.app(request_scope, receive, send)
        finally:
            current_user_id.reset(token)


REPO_ROOT = Path(__file__).resolve().parents[4]
dotenv.load_dotenv(REPO_ROOT / ".env", override=True)
supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])

mcp = FastMCP("alphchemy-mcp", stateless_http = True)

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
def avg_price(symbol: str) -> str:
    """Return the average close price for a symbol, such as BTC_USDT."""
    data = json.loads((REPO_ROOT / "data" / f"{symbol}.json").read_text())
    close = data["close"]
    return f"Average close price for {symbol}: {sum(close) / len(close):.3g}"


@mcp.tool()
def queue_experiment(title: str, source: str) -> str:
    """Queue an experiment for execution.

    Use `overview` first to understand the Alphchemy system.

    `title` is a short but descriptive label.
    `source` is the experiment source. Use `documentation("source/source_format")`
    for the source format."""
    user_id = current_user_id.get()
    return queue_experiment_tool(supabase, title, source, user_id)


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
    user_id = current_user_id.get()
    return queue_validated_tool(supabase, title, validation_id, user_id)


@mcp.tool()
def list_experiments(offset: int = 0) -> str:
    """List experiments, newest updated first.

    Returns up to 50 experiment summaries starting at `offset`."""
    user_id = current_user_id.get()
    return list_experiments_tool(supabase, offset, user_id)


@mcp.tool()
def query_experiments(query: str) -> str:
    """Query completed experiments using the line-oriented query DSL."""
    user_id = current_user_id.get()
    return query_experiments_tool(supabase, query, user_id)


@mcp.tool()
def status(experiment_id: int) -> str:
    """Return the status of an experiment."""
    user_id = current_user_id.get()
    return status_tool(supabase, experiment_id, user_id)


@mcp.tool()
def experiment_source(experiment_id: int) -> str:
    """Return the source text for one experiment."""
    user_id = current_user_id.get()
    return experiment_source_tool(supabase, experiment_id, user_id)

@mcp.tool()
def experiment_summary(experiment_id: int) -> str:
    """Return a compact summary of one experiment, excluding source."""
    user_id = current_user_id.get()
    return experiment_summary_tool(supabase, experiment_id, user_id)

@mcp.tool()
def results_summary(experiment_id: int) -> str:
    """Return compact per-fold metrics and timestamps."""
    user_id = current_user_id.get()
    return results_summary_tool(supabase, experiment_id, user_id)

@mcp.tool()
def experiment_paths(experiment_id: int, select: list[str]) -> str:
    """Query scalar paths from one experiment row."""
    user_id = current_user_id.get()
    return experiment_paths_tool(supabase, experiment_id, select, user_id)


@mcp.tool()
def convert(experiment_id: int, fold_idx: int, platform: str) -> str:
    """Convert a completed experiment fold to strategy code.

    `platform` currently only supports "pinescript".
    Returns the generated PineScript source."""
    user_id = current_user_id.get()
    return convert_tool(supabase, experiment_id, fold_idx, platform, user_id)


@mcp.tool()
def delete_experiment(experiment_id: int) -> str:
    """Delete an experiment by id.

    This is destructive, so confirm with the user before using it"""
    user_id = current_user_id.get()
    return delete_experiment_tool(supabase, experiment_id, user_id)


@mcp.tool()
def list_notebooks() -> str:
    """List available notebooks."""
    user_id = current_user_id.get()
    return list_notebooks_tool(supabase, user_id)


@mcp.tool()
def view_notebook(notebook_id: int) -> str:
    """View a single notebook by id"""
    user_id = current_user_id.get()
    return view_notebook_tool(supabase, notebook_id, user_id)


@mcp.tool()
def create_notebook(title: str, queries: list[str], notes: list[str]) -> str:
    """Create a notebook.

    Run the actual queries yourself before creating a notebook"""
    user_id = current_user_id.get()
    return create_notebook_tool(supabase, title, queries, notes, user_id)


@mcp.tool()
def update_notebook(notebook_id: int, title: str | None = None, queries: list[str] | None = None, notes: list[str] | None = None) -> str:
    """Update notebook content.

    Run the actual queries yourself before updating notebook queries."""
    user_id = current_user_id.get()
    return update_notebook_tool(supabase, notebook_id, title, queries, notes, user_id)


@mcp.tool()
def delete_notebook(notebook_id: int) -> str:
    """Delete a notebook by id.

    This is destructive, so confirm with the user before using it."""
    user_id = current_user_id.get()
    return delete_notebook_tool(supabase, notebook_id, user_id)


mcp_http_app = mcp.streamable_http_app()


@asynccontextmanager
async def lifespan(fastapi_app: FastAPI) -> AsyncIterator[None]:
    async with mcp.session_manager.run():
        yield


app = FastAPI(lifespan = lifespan)
app.mount("/", mcp_http_app)
app.add_middleware(ApiKeyMiddleware, supabase = supabase)


if __name__ == "__main__":
    uvicorn.run(app, host = "0.0.0.0", port = 8000)
