from __future__ import annotations

from analysis.path import apply_aggregate, numeric_values, resolve_path, MissingKeyError
from analysis.filters import Filter, NumericFilter, StrFilter, BoolFilter, TimestampFilter, matches_filters, parse_timestamp_value
from datetime import datetime
from typing import Annotated, Literal, TYPE_CHECKING
from pydantic import BaseModel, Field
import math
import re

if TYPE_CHECKING:
    from supabase import Client


class QueryResults(BaseModel):
    path: str
    values: list[bool | float | str]
    ids: list[int]
    skipped: int


class Selection(BaseModel):
    text: str
    path: str
    aggregate: Literal["mean", "max", "min", "std"] | None = None
    limit: int | None = 25
    offset: int = 0


def load_experiments(supabase: Client) -> list[dict]:
    table = supabase.table("experiments")
    selected = table.select("id, last_updated, title, experiment, results, status, user_id, is_public")
    filtered = selected.eq("status", "completed")
    return filtered.order("last_updated", desc = True).execute().data


def owned_experiments(experiments: list[dict], visibility: Literal["all", "public", "private"], user_id: str) -> list[dict]:
    if visibility == "public":
        return [experiment for experiment in experiments if experiment["is_public"]]
    if visibility == "private":
        return [experiment for experiment in experiments if not experiment["is_public"] and experiment["user_id"] == user_id]

    return [experiment for experiment in experiments if experiment["is_public"] or experiment["user_id"] == user_id]


def matched_experiments(experiments: list[dict], filters: list[Filter]) -> tuple[list[dict], int]:
    groups = [filters] if len(filters) > 0 else []
    matched = []
    skipped = 0

    for experiment in experiments:
        try:
            if matches_filters(experiment, groups):
                matched.append(experiment)
        except MissingKeyError:
            skipped += 1

    return matched, skipped


class Query(BaseModel):
    query: str
    select: list[Selection] = Field(default_factory = list, exclude = True)
    filters: list[Annotated[Filter, Field(discriminator = "type")]] = Field(default_factory = list, exclude = True)
    visibility: Literal["all", "public", "private"] = Field(default = "all", exclude = True)
    results: None | list[QueryResults] = None

    def build_numeric_filter(self, path: str, op: str, number: float) -> NumericFilter:
        if op == "==":
            return NumericFilter(path = path, eq = number)
        if op == ">=":
            return NumericFilter(path = path, gte = number)
        if op == ">":
            return NumericFilter(path = path, gt = number)
        if op == "<=":
            return NumericFilter(path = path, lte = number)
        if op == "<":
            return NumericFilter(path = path, lt = number)

        raise ValueError(f"Unknown operator: {op}")

    def build_timestamp_filter(self, path: str, op: str, timestamp: datetime) -> TimestampFilter:
        if op == "==":
            return TimestampFilter(path = path, eq = timestamp)
        if op == ">=":
            return TimestampFilter(path = path, gte = timestamp)
        if op == ">":
            return TimestampFilter(path = path, gt = timestamp)
        if op == "<=":
            return TimestampFilter(path = path, lte = timestamp)
        if op == "<":
            return TimestampFilter(path = path, lt = timestamp)

        raise ValueError(f"Unknown operator: {op}")

    def value_text(self, value_text: str) -> tuple[str, bool]:
        if value_text.startswith("\""):
            return value_text.strip("\""), True

        return value_text, False

    def build_filter(self, path: str, operator: str, value_text: str) -> Filter:
        text, is_quoted = self.value_text(value_text)

        try:
            timestamp = parse_timestamp_value(text)
            return self.build_timestamp_filter(path, operator, timestamp)
        except ValueError:
            pass

        if is_quoted:
            if operator != "==":
                raise ValueError(f"String filter only supports ==, got {operator}")

            return StrFilter(path = path, eq = text)

        if text == "true" or text == "false":
            if operator != "==":
                raise ValueError(f"Bool filter only supports ==, got {operator}")

            flag = text == "true"
            return BoolFilter(path = path, eq = flag)

        number = float(text)
        return self.build_numeric_filter(path, operator, number)

    def parse_filter(self, line: str) -> Filter:
        tokens = line.split()
        path = tokens[0]
        operator = tokens[1]
        value_text = " ".join(tokens[2:])
        return self.build_filter(path, operator, value_text)

    def parse_selection(self, line: str) -> Selection:
        aggregate_match = re.fullmatch(r"(mean|max|min|std)\((.+)\)", line)
        if aggregate_match is not None:
            aggregate = aggregate_match.group(1)
            path = aggregate_match.group(2)
            if "(" in path or ")" in path:
                raise ValueError("Selection wrappers cannot be nested")

            return Selection(text = line, path = path, aggregate = aggregate, limit = None)

        window_match = re.fullmatch(r"(\d+)(?:\+(\d+))?\((.+)\)", line)
        if window_match is not None:
            limit_text = window_match.group(1)
            limit = int(limit_text)
            if limit < 1:
                raise ValueError(f"limit must be between 1 and 25, got {limit}")
            if limit > 25:
                raise ValueError(f"limit must be between 1 and 25, got {limit}")

            offset_text = window_match.group(2)
            offset = int(offset_text) if offset_text is not None else 0
            path = window_match.group(3)
            if "(" in path or ")" in path:
                raise ValueError("Selection wrappers cannot be nested")

            return Selection(text = line, path = path, limit = limit, offset = offset)

        if "(" in line or ")" in line:
            raise ValueError(f"Invalid selection wrapper: {line}")

        return Selection(text = line, path = line)

    def parse_visibility(self, line: str) -> Literal["all", "public", "private"]:
        value = line.split(":", 1)[1].strip()

        if value == "all" or value == "public" or value == "private":
            return value

        raise ValueError(f"visibility must be all, public, or private, got {value}")

    def parse(self) -> None:
        self.select = []
        self.filters = []
        self.visibility = "all"
        section: str | None = None

        for line in self.query.split("\n"):
            stripped = line.strip()

            if len(stripped) == 0:
                continue

            if stripped == "select:":
                section = "select"
                continue

            if stripped == "filters:":
                section = "filters"
                continue

            if stripped.startswith("visibility:"):
                self.visibility = self.parse_visibility(stripped)
                section = None
                continue

            if section == "select":
                selection = self.parse_selection(stripped)
                if selection.path == "id":
                    raise ValueError("`id` cannot be selected")
                if selection.path == "user_id":
                    raise ValueError("`user_id` cannot be selected")

                self.select.append(selection)
            elif section == "filters":
                parsed_filter = self.parse_filter(stripped)
                if parsed_filter.path == "id":
                    raise ValueError("`id` cannot be filtered")
                if parsed_filter.path == "user_id":
                    raise ValueError("`user_id` cannot be filtered")

                self.filters.append(parsed_filter)
            else:
                raise ValueError(f"Line outside any section: {stripped}")

        if len(self.select) == 0:
            raise ValueError("Query must select at least one path")

    def set_results(self, experiments: list[dict]) -> None:
        matched, base_skipped = matched_experiments(experiments, self.filters)
        results: list[QueryResults] = []

        for selection in self.select:
            selected = matched
            if selection.limit is not None:
                end = selection.offset + selection.limit
                selected = matched[selection.offset:end]

            values: list[bool | float | str] = []
            ids: list[int] = []
            skipped = base_skipped

            for experiment in selected:
                try:
                    value = resolve_path(experiment, selection.path)
                except MissingKeyError:
                    skipped += 1
                    continue

                if isinstance(value, float) and not math.isfinite(value):
                    skipped += 1
                    continue

                values.append(value)
                ids.append(experiment["id"])

            if selection.aggregate is not None and len(values) > 0:
                nums = numeric_values(values)
                if len(nums) == 0:
                    raise ValueError(f"Aggregate {selection.aggregate} found no numeric values for {selection.path}")

                aggregate = apply_aggregate(selection.aggregate, nums)
                values = [aggregate]
                ids = []

            result = QueryResults(
                path = selection.text,
                values = values,
                ids = ids,
                skipped = skipped
            )
            results.append(result)

        self.results = results

    def run(self, supabase: Client, user_id: str) -> None:
        self.parse()
        experiments = load_experiments(supabase)
        visible = owned_experiments(experiments, self.visibility, user_id)
        self.set_results(visible)
