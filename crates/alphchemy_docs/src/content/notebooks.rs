pub const NOTEBOOKS: &str = r####"# Notebooks

This page describes **notebooks**, which store query tiles and notes.

Each query in a notebook must have only one note paired with it.

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

## Queries

Each entry in `queries` stores a query and its server-populated results. See `query` for the query object, result object, and syntax.

## Further reading

- query: Query objects, results, and syntax
"####;
