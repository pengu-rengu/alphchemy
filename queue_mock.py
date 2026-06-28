from __future__ import annotations

import os
from pathlib import Path

import dotenv
from supabase import Client, create_client

MOCK_SOURCES_DIR = "mock_sources"


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


def load_sources(project_dir: Path) -> list[str]:
    sources_dir = project_dir / MOCK_SOURCES_DIR
    paths = sorted(sources_dir.glob("*.txt"))
    return [path.read_text() for path in paths]


def queue_source(supabase: Client, source: str, experiment_number: int) -> None:
    payload = {
        "title": f"Mock Experiment {experiment_number}",
        "source": source,
        "status": "queued"
    }
    table = supabase.table("experiments")
    inserted = table.insert(payload)
    selected = inserted.select("id, title")
    rows = selected.execute().data
    row = rows[0]
    print(f"queued id={row['id']} title={row['title']}")


def queue_sources(supabase: Client, sources: list[str]) -> None:
    for source_index, source in enumerate(sources, start = 1):
        queue_source(supabase, source, source_index)

    count = len(sources)
    print(f"queued {count} experiments")


def main() -> None:
    project_dir = project_root()
    supabase = load_supabase(project_dir)
    sources = load_sources(project_dir)
    queue_sources(supabase, sources)


if __name__ == "__main__":
    main()
