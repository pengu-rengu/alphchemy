from analysis.query import Query
from datetime import datetime


def format_number(value: bool | float | str) -> str:
    if isinstance(value, float):
        return f"{value:.3g}"
    return str(value)


def format_value(value: bool | float | str) -> str:
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value)
            return parsed.strftime("%b %-d %Y %H:%M")
        except ValueError:
            return value

    return format_number(value)


def format_query_results(query: Query) -> str:
    lines = [f"[QUERY] {len(query.results)} path(s)"]

    for result in query.results:
        pairs: list[str] = []
        for i, value in enumerate(result.values):
            formatted = format_value(value)
            if len(result.ids) == 0:
                pairs.append(formatted)
            else:
                pairs.append(f"{formatted} ({result.ids[i]})")

        joined = ", ".join(pairs)
        lines.append("")
        lines.append(f"[RESULTS] {result.path}")
        lines.append(joined if len(result.values) > 0 else "—")
        if result.skipped > 0:
            lines.append(f"skipped: {result.skipped}")

    return "\n".join(lines) + "\n\n"
