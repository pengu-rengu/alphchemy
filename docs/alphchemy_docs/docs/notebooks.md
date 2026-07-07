# Notebook Description

A notebook is a list of tiles displayed top to bottom in order, where each tile is a query paired with an accompanying note. `queries` is an ordered list of query objects, each with a single `query` field holding a raw, SQL-style query string. `notes` is a list of note strings aligned by index with `queries`; `notes[i]` is the note for `queries[i]`, so both lists must have the same length. `title` is a short human-readable label for the submission. Query `results` are populated server-side.

__Before creating/modifying notebook queries, you should first run those queries using `query_experiments`__

Notebook Query Results Object:
```
{
    "path": str,
    "values": [array],
    "ids": [array of int],
    "skipped": int >= 0
}
```

Notebook Query Object:
```
{
    "query": str,
    "results": null or [array of notebook query results objects]
}
```

Notebook Object:
```
{
    "title": str,
    "queries": [array of notebook query objects],
    "notes": [array of str],
    "status": "idle" or "working" or "errored",
    "error_message": str or null
}
```

Newlines and indentation are significant in the query. Example:

    select:
        title
        results.mean:test_results.metrics.excess_sharpe
    filters:
        results.mean:test_results.metrics.excess_sharpe > 0
    limit: 10
    offset: 0

`select:` lists one path per indented line (required, at least one). Paths use dot notation over the experiment and results objects, include `title` and `last_edited`, and support per-fold aggregates with `<array_path>.<func>:<inner_path>` syntax for len, mean, std, min, and max, e.g. "experiment.strategy.stop_loss" or "results.mean:test_results.metrics.excess_sharpe". Aggregates can be nested, e.g. "results.mean:test_results.std:equity_curve.self". End an aggregate's inner path with `.self` to aggregate the elements of a leaf list (e.g. `equity_curve`) directly instead of indexing a dict key. `id` cannot be selected or filtered; each returned value is annotated with its experiment id in parentheses, e.g. `0.42 (100)`. ISO-8601 timestamp values are shown as `Jan 2 2026 12:00`. `filters:` lists one `path <op> value` per indented line (optional; all must match). Operators: >=, >, <=, <, == ; values are numbers, ISO timestamps like `2024-06-01T00:00:00` or `2024-06-01T00:00:00Z`, "quoted strings", or true/false. `limit: N` caps the number of experiments (optional, default 25, max 25). `offset: N` skips N matching experiments before applying limit (optional, default 0). Each query returns the raw selected values per path.
