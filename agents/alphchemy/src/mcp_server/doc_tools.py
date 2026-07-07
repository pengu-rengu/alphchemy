from __future__ import annotations

import json
from urllib.parse import quote
from urllib.request import urlopen

ALPHCHEMY_DESCRIPTION = """\
# Alphchemy

Alphchemy is a platform for running and analyzing experiments to optimize algorithmic trading strategies.

An experiment defines a trading strategy and evaluates it with cross-validated backtesting. A strategy turns numerical OHLC-derived features into entry/exit signals via a boolean logic or decision network, and a genetic algorithm optimizes that network to maximize the configured objective metrics on training data while validating on held-out data. Completed experiments store their per-fold backtest metrics.

__IMPORTANT NOTE__:
Some coins' close prices are large (BTC roughly $40,000-$100,000), so either make qty sufficiently small or make start_balance sufficiently large
"""


def fetch_docs_server(docs_server_url: str, path: str) -> str:
    base_url = docs_server_url.rstrip("/")
    url = f"{base_url}{path}"

    with urlopen(url) as response:
        body = response.read()

    return body.decode("utf-8")


def overview_tool(docs_server_url: str) -> str:
    return ALPHCHEMY_DESCRIPTION
    directory_text = fetch_docs_server(docs_server_url, "/directory")
    doc_paths = json.loads(directory_text)
    doc_lines = [f"- `{doc_path}`" for doc_path in doc_paths]
    directory = "\n".join(doc_lines)
    return f"{ALPHCHEMY_DESCRIPTION}\nDocs directory\n\n{directory}"

def documentation_tool(docs_server_url: str, path: str) -> str:
    return "Documentation unavailable"
    quoted_path = quote(path, safe="/")
    return fetch_docs_server(docs_server_url, f"/docs/{quoted_path}")
