from __future__ import annotations
from typing import Any
from supabase import Client
from analysis.format_analysis import format_query_results, format_number
from analysis.query import Query

def validate_notebook_parts(queries: list[Any], notes: list[str]) -> None:
    if len(queries) != len(notes):
        raise ValueError("queries and notes must have the same length")

def clear_query_results(queries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    cleared = []

    for query in queries:
        new_query = query.copy()
        new_query["results"] = None
        cleared.append(new_query)

    return cleared

def fetch_notebook_row(supabase: Client, notebook_id: int, user_id: str) -> dict[str, Any]:
    table = supabase.table("notebooks")
    selected = table.select("id, last_updated, title, queries, notes, status, error_message")
    owned = selected.eq("user_id", user_id)
    filtered = owned.eq("id", notebook_id)
    limited = filtered.limit(1)
    rows = limited.execute().data

    if len(rows) == 0:
        raise ValueError(f"notebook id={notebook_id} not found")

    return rows[0]

def query_experiments_tool(supabase: Client, query: str, user_id: str) -> str:
    parsed = Query(query = query)
    parsed.run(supabase, user_id)
    return format_query_results(parsed)

def list_notebooks_tool(supabase: Client, user_id: str) -> str:
    table = supabase.table("notebooks")
    selected = table.select("id, last_updated, title")
    owned = selected.eq("user_id", user_id)
    ordered = owned.order("last_updated", desc = True)
    rows = ordered.execute().data

    lines = [f"[NOTEBOOKS] {len(rows)} notebook(s)"]
    for row in rows:
        lines.append(f"id={row['id']} title={row['title']}")

    return "\n".join(lines)

def view_notebook_tool(supabase: Client, notebook_id: int, user_id: str) -> str:
    row = fetch_notebook_row(supabase, notebook_id, user_id)
    lines = [
        f"id: {row['id']}",
        f"last_updated: {row['last_updated']}",
        f"title: {row['title']}",
        f"status: {row['status']}"
    ]

    error_message = row["error_message"]
    if error_message:
        lines.append(error_message)

    queries = row["queries"]
    lines.append(f"tile_count: {len(queries)}")
    for i, query in enumerate(queries):
        lines.append(f"[TILE {i}]")
        lines.append("query:")
        lines.append(query["query"])
        lines.append(f"note: {row["notes"][i]}")

        results = query["results"]
        if not results:
            continue

        lines.append("results:")
        for result in results:
            lines.append(f"path: {result['path']}")
            formatted_values =  ", ".join([format_number(value) for value in result['values']])
            lines.append(f"values: {formatted_values}")
            lines.append(f"skipped: {result['skipped']}")

    return "\n".join(lines)


def create_notebook_tool(supabase: Client, title: str, queries: list[str], notes: list[str], user_id: str) -> str:
    validate_notebook_parts(queries, notes)

    status = "working" if len(queries) > 0 else "idle"

    table = supabase.table("notebooks")
    cleaned_title = title.strip()
    inserted = table.insert({
        "title": cleaned_title,
        "queries": [{"query": query, "results": None} for query in queries],
        "notes": notes,
        "status": status,
        "error_message": None,
        "user_id": user_id
    })
    notebook_id = inserted.execute().data[0]["id"]
    return f"created notebook id={notebook_id}"


def update_notebook_tool(supabase: Client, notebook_id: int, title: str | None, queries: list[str] | None, notes: list[str] | None, user_id: str) -> str:
    notebook = fetch_notebook_row(supabase, notebook_id, user_id)
    values: dict[str, Any] = {
        "queries": clear_query_results(notebook["queries"]),
        "status": "working",
        "error_message": None,
        "last_updated": "now"
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
    owned = updated.eq("user_id", user_id)
    filtered = owned.eq("id", notebook_id)
    filtered.execute()
    return f"updated notebook id={notebook_id}"

def delete_notebook_tool(supabase: Client, notebook_id: int, user_id: str) -> str:
    fetch_notebook_row(supabase, notebook_id, user_id)
    table = supabase.table("notebooks")
    deleted = table.delete()
    owned = deleted.eq("user_id", user_id)
    owned.eq("id", notebook_id).execute()
    return f"deleted notebook id={notebook_id}"
