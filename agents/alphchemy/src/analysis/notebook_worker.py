from __future__ import annotations

from typing import Any
from analysis.query import SelectQuery
from supabase import Client

def fetch_next_working_notebook(supabase: Client) -> dict[str, Any] | None:
    table = supabase.table("notebooks")
    selected = table.select("*")
    filtered = selected.eq("status", "working")
    ordered = filtered.order("last_edited")
    rows = ordered.limit(1).execute().data

    if not rows:
        return None

    return rows[0]


def write_idle_notebook(supabase: Client, notebook_id: int, queries: list[dict]) -> None:
    table = supabase.table("notebooks")
    values = {"queries": queries, "status": "idle", "error_message": None, "last_edited": "now"}
    updated = table.update(values)
    updated.eq("id", notebook_id).execute()


def write_errored_notebook(supabase: Client, notebook_id: int, message: str) -> None:
    table = supabase.table("notebooks")
    updated = table.update({"status": "errored", "error_message": message, "last_edited": "now"})
    filtered = updated.eq("id", notebook_id)
    filtered.execute()


def run_queries(queries: list[dict], supabase: Client) -> list[dict]:
    results: list[dict] = []

    for entry in queries:
        query_entry = entry.copy()
        query_entry.pop("results", None)
        query = SelectQuery.model_validate(query_entry)
        query.run(supabase)
        dumped = query.model_dump(by_alias = True)
        results.append(dumped)

    return results


def process_working_notebook(supabase: Client) -> bool:
    row = fetch_next_working_notebook(supabase)

    if row is None:
        return False

    notebook_id = row["id"]

    print(f"running notebook id={notebook_id}")

    try:
        queries = row["queries"]
        new_queries = run_queries(queries, supabase)
        write_idle_notebook(supabase, notebook_id, new_queries)
        print(f"completed notebook id={notebook_id}")

    except Exception as error:
        print(f"notebook run failed id={notebook_id}: {error}")
        write_errored_notebook(supabase, notebook_id, f"{error}")

    return True
