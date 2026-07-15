# Notebooks

This page describes **notebooks**, which store query tiles and notes.

Each notebook tile pairs one query with one note. Query results are populated server-side.

## Notebook Object

**Fields:**
- `title`:
    - description: notebook title
    - constraints: must be a string
- `queries`:
    - description: ordered list of query objects
    - constraints: must have the same length as `notes`
- `notes`:
    - description: ordered list of note strings
    - constraints: must have the same length as `queries`
- `status`:
    - description: notebook worker status
    - constraints: must be `idle`, `working`, or `errored`
- `error_message`:
    - description: worker error message
    - constraints: must be a string or `null`

**Format:**
```
{
    "title": str,
    "queries": [array of notebook query objects],
    "notes": [array of str],
    "status": "idle" or "working" or "errored",
    "error_message": str or null
}
```

## Query Object

**Fields:**
- `query`:
    - description: raw query string
    - constraints: must be a string
- `results`:
    - description: query results populated server-side
    - constraints: must be `null` or a list of query result objects

**Format:**
```
{
    "query": str,
    "results": null or [array of notebook query results objects]
}
```

## Query Result Object

**Fields:**
- `path`:
    - description: original selection text
    - constraints: must be a string
- `values`:
    - description: selected values for the path
    - constraints: must be an array
- `ids`:
    - description: experiment ids corresponding to window-selected values; empty for aggregate selections
    - constraints: must be an array of integers
- `skipped`:
    - description: number of skipped values
    - constraints: must be integer >= 0

**Format:**
```
{
    "path": str,
    "values": [array],
    "ids": [array of int],
    "skipped": int >= 0
}
```

## Query Syntax

Newlines and indentation are significant in notebook queries.

**Example:**

```
select:
    title
    10(results.mean:test_results.metrics.excess_sharpe)
    mean(results.mean:test_results.metrics.excess_sharpe)
filters:
    results.mean:test_results.metrics.excess_sharpe > 0
sort_desc: results.mean:test_results.metrics.excess_sharpe
visibility: public
```

**Fields:**
- `select`:
    - description: selected paths or selection wrappers, one per indented line
    - constraints: required, must contain at least one path
- `filters`:
    - description: filters applied to matching experiments
    - constraints: optional, all filters must match
- `sort_asc` or `sort_desc`:
    - description: path used to order matching experiments before selection windows
    - constraints: optional, mutually exclusive, must resolve to finite numbers or timestamps
- `visibility`:
    - description: experiment visibility included by the query
    - constraints: optional, must be `all`, `public`, or `private`; defaults to `all`

A bare `<path>` returns values from the first 25 matching experiments. `<limit>(<path>)` changes the per-path limit, and `<limit>+<offset>(<path>)` also skips matching experiments before resolving that path. Limits must be between 1 and 25; offsets must be nonnegative.

`mean(<path>)`, `max(<path>)`, `min(<path>)`, and `std(<path>)` aggregate numeric values across every matching experiment instead of returning experiment values individually. Booleans are treated as `0.0` or `1.0`, and `std` is population standard deviation. Aggregate results contain one value and no experiment ids. Selection wrappers cannot be nested.

Paths use dot notation over experiment and results objects. Per-fold aggregates use `<array_path>.<func>:<inner_path>` syntax. Supported aggregate functions are `len`, `mean`, `std`, `min`, and `max`.

Aggregate paths can end with `.self` to aggregate leaf-list elements directly, such as `results.mean:test_results.std:equity_curve.self`.

`id` cannot be selected, filtered, or sorted. Window-selected values are annotated with experiment ids in parentheses; aggregate values are not.

Filter operators are `>=`, `>`, `<=`, `<`, and `==`. Filter values can be numbers, ISO timestamps, quoted strings, or booleans.

`sort_asc: <path>` and `sort_desc: <path>` are mutually exclusive. Sort paths support finite numbers and timestamps, including aggregate paths. Sorting happens after filtering and before each selection's offset and limit. Experiments with missing or non-finite sort values are skipped. Without a sort field, experiments remain ordered by `last_updated` descending.

Frontend and MCP notebook queries include public experiments and private experiments owned by the notebook user when visibility is `all`. `public` includes only public experiments, while `private` includes only private experiments owned by the notebook user.

## Further reading

- results: Experiment result paths available to notebook queries
- source/source_format: Experiment source structure
