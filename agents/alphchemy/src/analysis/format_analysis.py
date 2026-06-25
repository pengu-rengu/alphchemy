from analysis.query import Query


def format_query_results(query: Query) -> str:
    if query.results is None:
        return "[QUERY] not run\n\n"

    lines = [f"[QUERY] {len(query.results)} path(s)"]

    for result in query.results:
        joined = ", ".join(str(value) for value in result.values)
        lines.append("")
        lines.append(f"[RESULTS] {result.path}")
        lines.append(joined if len(result.values) > 0 else "—")
        lines.append(f"skipped: {result.skipped}")

    return "\n".join(lines) + "\n\n"
