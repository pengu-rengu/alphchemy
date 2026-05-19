from analysis.query import SelectQuery, SearchQuery


def format_select_results(query: SelectQuery) -> str:
    if query.results is None:
        return "[QUERY] not run\n\n"

    if len(query.results) == 0:
        return "[QUERY] 0 matched\n\n"

    lines = [f"[QUERY] {len(query.select)} path(s) summarized"]

    for path, result in zip(query.select, query.results):
        lines.append("")
        lines.append(f"[SUMMARY] {path}")
        lines.append(f"min: {round(result.min_, 6)}")
        lines.append(f"q1: {round(result.q1, 6)}")
        lines.append(f"median: {round(result.median, 6)}")
        lines.append(f"q3: {round(result.q3, 6)}")
        lines.append(f"max: {round(result.max_, 6)}")

    return "\n".join(lines) + "\n\n"


def format_search_results(query: SearchQuery) -> str:
    if query.results is None:
        return "[SEARCH] not run\n\n"

    ids = ", ".join(str(experiment_id) for experiment_id in query.results)
    return f"[SEARCH] {len(query.results)} matched\nids: {ids}\n\n"
