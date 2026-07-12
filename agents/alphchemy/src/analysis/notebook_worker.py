from __future__ import annotations

import os
import sys
import time
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import dotenv
from analysis.query import Query
from supabase import Client, create_client

POLL_INTERVAL_SEC = 2

def fetch_next_working_notebook(supabase: Client) -> dict[str, Any] | None:
    table = supabase.table("notebooks")
    selected = table.select("*")
    filtered = selected.eq("status", "working")
    ordered = filtered.order("last_updated")
    rows = ordered.limit(1).execute().data

    if not rows:
        return None

    return rows[0]


def write_idle_notebook(supabase: Client, notebook_id: int, queries: list[dict]) -> None:
    table = supabase.table("notebooks")
    values = {"queries": queries, "status": "idle", "error_message": None, "last_updated": "now"}
    updated = table.update(values)
    updated.eq("id", notebook_id).execute()


def write_errored_notebook(supabase: Client, notebook_id: int, message: str) -> None:
    table = supabase.table("notebooks")
    updated = table.update({"status": "errored", "error_message": message, "last_updated": "now"})
    filtered = updated.eq("id", notebook_id)
    filtered.execute()


def run_queries(queries: list[dict], supabase: Client, user_id: str) -> list[dict]:
    results: list[dict] = []

    for entry in queries:
        query_entry = entry.copy()
        query_entry.pop("results", None)
        query = Query.model_validate(query_entry)
        query.run(supabase, user_id)
        results.append(query.model_dump())

    return results


def process_working_notebook(supabase: Client) -> bool:
    row = fetch_next_working_notebook(supabase)

    if row is None:
        return False

    notebook_id = row["id"]

    print(f"running notebook id={notebook_id}")

    try:
        queries = row["queries"]
        user_id = row["user_id"]
        new_queries = run_queries(queries, supabase, user_id)
        write_idle_notebook(supabase, notebook_id, new_queries)
        print(f"completed notebook id={notebook_id}")

    except Exception as error:
        print(f"notebook run failed id={notebook_id}: {error}")
        write_errored_notebook(supabase, notebook_id, f"{error}")

    return True


def main():
    repo_root = Path(__file__).resolve().parents[4]
    dotenv.load_dotenv(repo_root / ".env", override = True)

    supabase_url = os.environ["SUPABASE_URL"]
    supabase_key = os.environ["SUPABASE_KEY"]
    supabase = create_client(supabase_url, supabase_key)

    while True:
        handled = process_working_notebook(supabase)
        if handled:
            continue

        print("idle")
        time.sleep(POLL_INTERVAL_SEC)


if __name__ == "__main__":
    main()
