# Query

This page describes **queries**, which select and aggregate completed experiment data.

Queries can be run directly or stored in notebook tiles.

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
    "results": null or [array of query result objects]
}
```

## Query Syntax

Newlines and indentation are significant in queries.

**Example:**

```
select:
    title
    10+5(results.mean:test_results.metrics.excess_sharpe)
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

### Selection Windows

- `<path>` returns values from the first 25 matching experiments.
- `<limit>(<path>)` returns up to `limit` values.
- `<limit>+<offset>(<path>)` skips `offset` matching experiments, then returns up to `limit` values. For example, `10+50(title)` skips 50 matching experiments and returns up to 10 titles.

Limits must be between 1 and 25. Offsets must be nonnegative. Filtering and sorting happen before each selection's offset and limit.

### Aggregate Selectors

- `mean(<path>)` returns the arithmetic mean.
- `min(<path>)` returns the minimum and the first experiment id with that value.
- `max(<path>)` returns the maximum and the first experiment id with that value.
- `std(<path>)` returns the population standard deviation.

Aggregate selectors use numeric values from every matching experiment and return one value. Booleans are treated as `0.0` or `1.0`. `mean` and `std` do not include an experiment id. Selection wrappers cannot be nested, so aggregate selectors cannot contain limit or offset selectors.

Paths use dot notation over experiment and results objects. Per-fold aggregates use `<array_path>.<func>:<inner_path>` syntax. Supported aggregate functions are `len`, `mean`, `std`, `min`, and `max`.

Aggregate paths can end with `.self` to aggregate leaf-list elements directly, such as `results.mean:test_results.std:equity_curve.self`.

`id` cannot be selected, filtered, or sorted. Window-selected values are annotated with experiment ids in parentheses.

Filter operators are `>=`, `>`, `<=`, `<`, and `==`. Filter values can be numbers, ISO timestamps, quoted strings, or booleans.

`sort_asc: <path>` and `sort_desc: <path>` are mutually exclusive. Sort paths support finite numbers and timestamps, including aggregate paths. Sorting happens after filtering and before each selection's offset and limit. Experiments with missing or non-finite sort values are skipped. Without a sort field, experiments remain ordered by `last_updated` descending.

Frontend and MCP queries include public experiments and private experiments owned by the user when visibility is `all`. `public` includes only public experiments, while `private` includes only private experiments owned by the user.

## Further reading

- notebooks: Notebook objects and query tiles
- results: Experiment result paths available to queries
- source/source_format: Experiment source structure
