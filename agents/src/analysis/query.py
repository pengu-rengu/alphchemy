from analysis.json_path import resolve_path
from analysis.filters import ExperimentFilter, matches_filters
from agents.data_paths import experiments_path
import statistics
import json


def load_experiments(skip_errors: bool = True) -> list[dict]:
    path = experiments_path()
    experiments: list[dict] = []

    with open(path, "r") as file:
        for line_index, line in enumerate(file):
            stripped = line.strip()

            if not stripped:
                continue

            try:
                data = json.loads(stripped)
            except json.JSONDecodeError:
                continue

            if skip_errors and "error" in data.get("results", {}):
                continue

            data["_line_index"] = line_index
            experiments.append(data)

    return experiments


def compute_quantile(sorted_values: list[float], fraction: float) -> float:
    last_index = len(sorted_values) - 1

    if last_index == 0:
        return sorted_values[0]

    position = fraction * last_index
    lower_index = int(position)
    upper_index = lower_index + 1

    if upper_index > last_index:
        return sorted_values[last_index]

    weight = position - lower_index
    lower_value = sorted_values[lower_index]
    upper_value = sorted_values[upper_index]
    interpolated = lower_value + weight * (upper_value - lower_value)

    return interpolated


def _format_value(value: object) -> str:
    if isinstance(value, float):
        return str(round(value, 6))

    if isinstance(value, list):
        formatted_items = [_format_value(item) for item in value]
        joined = ", ".join(formatted_items)
        return f"[{joined}]"

    return str(value)


def _sort_key(experiment: dict, sort_path: str, descending: bool) -> tuple[int, float]:
    resolved = resolve_path(experiment, sort_path)

    if len(resolved) == 0:
        return (1, 0.0)

    value = resolved[0]

    if not isinstance(value, (int, float)):
        return (1, 0.0)

    numeric = float(value)

    if descending:
        numeric = -numeric

    return (0, numeric)


def query_experiments(
    select: list[str],
    filter_groups: list[list[ExperimentFilter]] | None = None,
    sort_by: str | None = None,
    sort_desc: bool = True,
    limit: int = 20,
    skip_errors: bool = True
) -> str:
    experiments = load_experiments(skip_errors)
    active_groups = filter_groups or []
    matched = [exp for exp in experiments if matches_filters(exp, active_groups)]
    total_matched = len(matched)

    if total_matched == 0:
        return "[QUERY] 0 matched\n\n"

    if sort_by is not None:
        matched.sort(key=lambda exp: _sort_key(exp, sort_by, sort_desc))

    shown = matched[:limit]
    shown_count = len(shown)

    lines = [f"[QUERY] {total_matched} matched, showing {shown_count}"]

    for experiment in shown:
        line_index = experiment["_line_index"]
        lines.append(f"\n--- Experiment {line_index} ---")

        for path in select:
            resolved = resolve_path(experiment, path)

            if len(resolved) == 0:
                lines.append(f"{path}: <missing>")
            else:
                lines.append(f"{path}: {_format_value(resolved[0])}")

    return "\n".join(lines) + "\n\n"


def _collect_numeric_values(experiments: list[dict], path: str) -> list[float]:
    values: list[float] = []

    for experiment in experiments:
        resolved = resolve_path(experiment, path)

        if len(resolved) == 0:
            continue

        value = resolved[0]

        if isinstance(value, (int, float)):
            values.append(float(value))

    return values


def summarize_field(
    path: str,
    filter_groups: list[list[ExperimentFilter]] | None = None,
    skip_errors: bool = True
) -> str:
    experiments = load_experiments(skip_errors)
    active_groups = filter_groups or []
    matched = [exp for exp in experiments if matches_filters(exp, active_groups)]
    matched_count = len(matched)

    if matched_count == 0:
        return "[ERROR] No experiments matched the requested filters.\n\n"

    values = _collect_numeric_values(matched, path)

    if len(values) == 0:
        return f"[ERROR] Path `{path}` has no numeric values after filtering.\n\n"

    sorted_values = sorted(values)
    mean = statistics.mean(sorted_values)
    std = statistics.pstdev(sorted_values)

    lines = [
        "[SUMMARY]",
        f"path: {path}",
        f"experiments_matched: {matched_count}",
        f"values_used: {len(values)}",
        f"min: {sorted_values[0]}",
        f"q1: {compute_quantile(sorted_values, 0.25)}",
        f"median: {compute_quantile(sorted_values, 0.5)}",
        f"q3: {compute_quantile(sorted_values, 0.75)}",
        f"max: {sorted_values[-1]}",
        f"mean: {mean}",
        f"std: {std}"
    ]

    return "\n".join(lines) + "\n\n"
