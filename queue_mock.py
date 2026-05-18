from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, cast

import dotenv
from supabase import Client, create_client

MOCK_EXPERIMENTS_FILE = "mock_experiments.json"


def project_root() -> Path:
    script_path = Path(__file__)
    resolved_path = script_path.resolve()
    return resolved_path.parent


def load_supabase(project_dir: Path) -> Client:
    env_path = project_dir / ".env"
    dotenv.load_dotenv(env_path, override = True)
    supabase_url = os.environ["SUPABASE_URL"]
    supabase_key = os.environ["SUPABASE_KEY"]
    client = create_client(supabase_url, supabase_key)
    return client


def load_experiments(project_dir: Path) -> list[dict[str, Any]]:
    experiments_path = project_dir / MOCK_EXPERIMENTS_FILE
    with experiments_path.open() as experiments_file:
        data = json.load(experiments_file)

    experiments = cast(list[dict[str, Any]], data)
    return experiments


def make_payload(experiment: dict[str, Any], experiment_number: int) -> dict[str, Any]:
    title = f"Mock Experiment {experiment_number}"
    status = "queued"
    payload = {
        "title": title,
        "experiment": experiment,
        "status": status
    }
    return payload


def queue_experiment(supabase: Client, experiment: dict[str, Any], experiment_number: int) -> None:
    payload = make_payload(experiment, experiment_number)
    table = supabase.table("experiments")
    inserted = table.insert(payload)
    selected = inserted.select("id, title")
    response = selected.execute()
    rows = response.data
    row = rows[0]
    row_id = row["id"]
    title = row["title"]
    print(f"queued id={row_id} title={title}")


def queue_experiments(supabase: Client, experiments: list[dict[str, Any]]) -> None:
    for experiment_index, experiment in enumerate(experiments, start = 1):
        queue_experiment(supabase, experiment, experiment_index)

    count = len(experiments)
    print(f"queued {count} experiments")


def main() -> None:
    project_dir = project_root()
    supabase = load_supabase(project_dir)
    experiments = load_experiments(project_dir)
    queue_experiments(supabase, experiments)


if __name__ == "__main__":
    main()
