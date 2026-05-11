from __future__ import annotations

from analysis.path import resolve_path
from analysis.filters import FilterModel, matches_filters
from typing import Any, TYPE_CHECKING
import statistics

if TYPE_CHECKING:
    from supabase import Client


def has_error_result(results: Any) -> bool:
    if not isinstance(results, dict):
        return False

    return "error" in results


def load_experiments(supabase: Client) -> list[dict]:
    table = supabase.table("experiments")
    selected = table.select("id, experiment, results, status")
    completed = selected.eq("status", "completed")
    non_null = completed.not_.is_("results", "null")
    rows = non_null.execute().data

    experiments: list[dict] = []

    for row in rows:
        status = row.get("status")

        if status != "completed":
            continue

        results = row.get("results")

        if results is None:
            continue

        if has_error_result(results):
            continue

        experiment = row.get("experiment")
        experiment_id = row.get("id")
        data = {
            "experiment": experiment,
            "results": results,
            "_experiment_id": experiment_id
        }
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


def format_value(value: str | bool | float) -> str:
    if isinstance(value, float):
        return str(round(value, 6))

    return str(value)


def require_numeric(value: str | bool | float, path: str) -> float:
    if isinstance(value, bool):
        raise Exception(f"Path `{path}` must resolve to a numeric value")

    if isinstance(value, str):
        raise Exception(f"Path `{path}` must resolve to a numeric value")

    return value


def sort_key(experiment: dict, sort_path: str, descending: bool) -> tuple[int, float]:
    resolved = resolve_path(experiment, sort_path)
    numeric = require_numeric(resolved, sort_path)

    if descending:
        numeric = -numeric

    return (0, numeric)


def matched_experiments(supabase: Client, filter_groups: list[list[FilterModel]] | None = None) -> list[dict]:
    experiments = load_experiments(supabase)
    active_groups = filter_groups or []

    matched = []

    for experiment in experiments:
        if matches_filters(experiment, active_groups):
            matched.append(experiment)

    return matched

def append_query_rows(lines: list[str], experiments: list[dict], select: list[str]) -> None:
    for experiment in experiments:
        experiment_id = experiment["_experiment_id"]
        lines.append(f"\n--- Experiment {experiment_id} ---")

        for path in select:
            resolved = resolve_path(experiment, path)
            lines.append(f"{path}: {format_value(resolved)}")


def collect_numeric_values(experiments: list[dict], path: str) -> list[float]:
    values: list[float] = []

    for experiment in experiments:
        resolved = resolve_path(experiment, path)
        numeric = require_numeric(resolved, path)
        values.append(numeric)

    return values


def append_summary(lines: list[str], experiments: list[dict], path: str) -> None:
    values = collect_numeric_values(experiments, path)
    sorted_values = sorted(values)
    mean = statistics.mean(sorted_values)
    std = statistics.pstdev(sorted_values)

    lines.append("")
    lines.append("[SUMMARY]")
    lines.append(f"path: {path}")
    lines.append(f"experiments_matched: {len(experiments)}")
    lines.append(f"values_used: {len(values)}")
    lines.append(f"min: {format_value(sorted_values[0])}")
    lines.append(f"q1: {format_value(compute_quantile(sorted_values, 0.25))}")
    lines.append(f"median: {format_value(compute_quantile(sorted_values, 0.5))}")
    lines.append(f"q3: {format_value(compute_quantile(sorted_values, 0.75))}")
    lines.append(f"max: {format_value(sorted_values[-1])}")
    lines.append(f"mean: {format_value(mean)}")
    lines.append(f"std: {format_value(std)}")


def query_experiments(supabase: Client, select: list[str], filter_groups: list[list[FilterModel]] | None = None, sort_by: str | None = None, sort_desc: bool = True, limit: int = 20
) -> str:
    matched = matched_experiments(supabase, filter_groups)
    total_matched = len(matched)

    if total_matched == 0:
        return "[QUERY] 0 matched\n\n"

    if sort_by is not None:
        matched.sort(key = lambda experiment: sort_key(experiment, sort_by, sort_desc))

    shown = matched[:limit]
    shown_count = len(shown)

    lines = [f"[QUERY] {total_matched} matched, showing {shown_count}"]
    append_query_rows(lines, shown, select)

    for path in select:
        append_summary(lines, matched, path)

    return "\n".join(lines) + "\n\n"
