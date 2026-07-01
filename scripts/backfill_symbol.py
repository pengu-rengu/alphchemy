"""One-time migration: add a `symbol` field to every experiments row.

Backfills the default pair BTC_USDT into both the `source` (keyed-yaml text) and
`experiment` (jsonb) columns. Idempotent — rows already carrying a symbol are left
untouched, so it is safe to re-run.

Run: pip install -r requirements.txt && python backfill_symbol.py
Needs SUPABASE_URL and SUPABASE_KEY in the environment (see repo .env).
"""

import os

import dotenv
from supabase import create_client

SYMBOL_VALUE = "BTC_USDT"
SYMBOL_LINE = f"symbol: {SYMBOL_VALUE}"


def add_symbol_to_source(source: str) -> str:
    if "symbol:" in source:
        return source
    return f"{SYMBOL_LINE}\n{source}"


def add_symbol_to_experiment(experiment: dict | None) -> dict | None:
    if experiment is None:
        return None
    if "symbol" in experiment:
        return experiment
    experiment["symbol"] = SYMBOL_VALUE
    return experiment


def main() -> None:
    dotenv.load_dotenv()
    client = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])

    read_table = client.table("experiments")
    rows = read_table.select("id, source, experiment").execute().data

    for row in rows:
        new_source = add_symbol_to_source(row["source"])
        new_experiment = add_symbol_to_experiment(row["experiment"])

        write_table = client.table("experiments")
        update = write_table.update({"source": new_source, "experiment": new_experiment})
        filtered = update.eq("id", row["id"])
        filtered.execute()
        print(f"updated id={row['id']}")


if __name__ == "__main__":
    main()
