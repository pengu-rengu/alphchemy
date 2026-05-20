from __future__ import annotations

import os
import time
from typing import Any

import dotenv
from agents.agent_system import AgentSystem
from agents.state import make_initial_state
from analysis.notebook_worker import process_working_notebook
from analysis.query import load_experiments
from openrouter import OpenRouter
from supabase import Client, create_client

POLL_INTERVAL_SEC = 2


def fetch_next_created(supabase: Client) -> dict[str, Any] | None:
    table = supabase.table("agent_systems")
    selected = table.select("*")
    filtered = selected.eq("status", "created")
    ordered = filtered.order("last_edited")
    rows = ordered.limit(1).execute().data

    if not rows:
        return None

    return rows[0]

def fetch_next_working_prompt(supabase: Client) -> dict[str, Any] | None:
    table = supabase.table("agent_systems")
    selected = table.select("*")
    filtered = selected.eq("status", "working")
    ordered = filtered.order("last_edited")
    rows = ordered.limit(1).execute().data

    if not rows:
        return None

    return rows[0]

def write_idle_state(supabase: Client, agent_id: int, state: dict[str, Any]) -> None:
    table = supabase.table("agent_systems")
    updated = table.update({"state": state, "status": "idle"})
    updated.eq("id", agent_id).execute()

def write_errored_status(supabase: Client, agent_id: int) -> None:
    table = supabase.table("agent_systems")
    updated = table.update({"status": "errored"})
    filtered = updated.eq("id", agent_id)
    filtered.execute()

def append_submission(supabase: Client, agent_id: int, proposal_state: dict[str, Any]) -> None:
    entry = {
        "type": proposal_state["type"],
        "submission": proposal_state["submission"]
    }
    table = supabase.table("agent_systems")
    selected = table.select("submissions")
    filtered = selected.eq("id", agent_id)
    limited = filtered.limit(1)
    rows = limited.execute().data
    current = rows[0]["submissions"]
    new_submissions = current + [entry]
    updated = table.update({"submissions": new_submissions})
    updated.eq("id", agent_id).execute()


def process_created(supabase: Client) -> bool:
    row = fetch_next_created(supabase)

    if row is None:
        return False

    agent_id = row["id"]

    try:
        system = AgentSystem.model_validate(row["schema"])
        additional_instructions_map = {agent.id: agent.additional_instructions for agent in system.agents}
        state = make_initial_state([agent.id for agent in system.agents], additional_instructions_map)
        write_idle_state(supabase, agent_id, state)
        print(f"initialized id={agent_id}")
        return True

    except Exception as error:
        print(f"created init failed id={agent_id}: {error}")
        write_errored_status(supabase, agent_id)

    return True


def process_working_prompt(supabase: Client, open_router: OpenRouter) -> bool:
    row = fetch_next_working_prompt(supabase)

    if row is None:
        return False

    agent_id = row["id"]

    print(f"running id={agent_id}")

    try:
        system = AgentSystem.model_validate(row["schema"])
        system.build_graph(open_router, supabase = supabase)
        user_prompt = row["user_prompt"] or ""
        new_state = system.run(row["state"], user_prompt, supabase = supabase, row_id = agent_id)
        append_submission(supabase, agent_id, new_state["proposal_state"])
        write_idle_state(supabase, agent_id, new_state)
        print(f"completed id={agent_id}")

    except Exception as error:
        print(f"run failed id={agent_id}: {error}")
        write_errored_status(supabase, agent_id)

    return True


def main():
    dotenv.load_dotenv("../../.env", override = True)

    supabase_url = os.environ["SUPABASE_URL"]
    supabase_key = os.environ["SUPABASE_KEY"]
    supabase = create_client(supabase_url, supabase_key)

    api_key = os.environ["OPENROUTER_KEY"]
    open_router = OpenRouter(api_key = api_key)

    while True:
        handled_created = process_created(supabase)
        if handled_created:
            continue

        handled_prompt = process_working_prompt(supabase, open_router)

        if handled_prompt:
            continue

        handled_notebook = process_working_notebook(supabase)

        if handled_notebook:
            continue

        print("idle")
        time.sleep(POLL_INTERVAL_SEC)


if __name__ == "__main__":
    main()
