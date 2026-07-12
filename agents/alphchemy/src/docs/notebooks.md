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
    - description: selected path
    - constraints: must be a string
- `values`:
    - description: selected values for the path
    - constraints: must be an array
- `ids`:
    - description: experiment ids corresponding to selected values
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
    results.mean:test_results.metrics.excess_sharpe
filters:
    results.mean:test_results.metrics.excess_sharpe > 0
visibility: public
limit: 10
offset: 0
```

**Fields:**
- `select`:
    - description: selected paths, one per indented line
    - constraints: required, must contain at least one path
- `filters`:
    - description: filters applied to matching experiments
    - constraints: optional, all filters must match
- `visibility`:
    - description: experiment visibility included by the query
    - constraints: optional, must be `all`, `public`, or `private`; defaults to `all`
- `limit`:
    - description: maximum number of experiments returned
    - constraints: optional, defaults to 25, max 25
- `offset`:
    - description: number of matching experiments skipped before applying `limit`
    - constraints: optional, defaults to 0

Paths use dot notation over experiment and results objects. Per-fold aggregates use `<array_path>.<func>:<inner_path>` syntax. Supported aggregate functions are `len`, `mean`, `std`, `min`, and `max`.

Aggregate paths can end with `.self` to aggregate leaf-list elements directly, such as `results.mean:test_results.std:equity_curve.self`.

`id` cannot be selected or filtered. Returned values are annotated with experiment ids in parentheses.

Filter operators are `>=`, `>`, `<=`, `<`, and `==`. Filter values can be numbers, ISO timestamps, quoted strings, or booleans.

Frontend notebook queries include public experiments and private experiments owned by the notebook user when visibility is `all`. `public` includes only public experiments, while `private` includes only private experiments owned by the notebook user. Direct MCP queries are unrestricted by user ownership.

## Further reading

- results: Experiment result paths available to notebook queries
- source/source_format: Experiment source structure
