from __future__ import annotations
from docs.serve_docs import list_doc_paths, read_doc

ALPHCHEMY_DESCRIPTION = """\
# Alphchemy

Alphchemy is a platform for running and analyzing experiments to optimize algorithmic trading strategies.

An experiment defines a trading strategy and evaluates it with cross-validated backtesting. A strategy turns numerical OHLC-derived features into entry/exit signals via a boolean logic or decision network, and a genetic algorithm optimizes that network to maximize the configured objective metrics on training data while validating on held-out data. Completed experiments store their per-fold backtest metrics.

__IMPORTANT NOTE__:
Some coins' close prices are large (BTC roughly $40,000-$100,000), so either make qty sufficiently small or make start_balance sufficiently large
"""


def overview_tool() -> str:
    doc_paths = list_doc_paths()
    doc_lines = []

    for doc_path in doc_paths:
        line = f"- `{doc_path}`"
        doc_lines.append(line)

    directory = "\n".join(doc_lines)
    return f"{ALPHCHEMY_DESCRIPTION}\nDocs directory\n\n{directory}"


def documentation_tool(path: str) -> str:
    return read_doc(path)
