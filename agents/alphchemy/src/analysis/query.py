from __future__ import annotations

from analysis.path import resolve_path, MissingKeyError
from analysis.filters import Filter, NumericFilter, StrFilter, BoolFilter, TimestampFilter, matches_filters, parse_timestamp_value
from datetime import datetime
from typing import Annotated, TYPE_CHECKING
from pydantic import BaseModel, Field
import math

if TYPE_CHECKING:
    from supabase import Client


class QueryResults(BaseModel):
    path: str
    values: list[bool | float | str]
    ids: list[int]
    skipped: int


def load_experiments(supabase: Client) -> list[dict]:
    table = supabase.table("experiments")
    selected = table.select("id, last_updated, title, experiment, results, status")
    filtered = selected.eq("status", "completed")
    return filtered.order("last_updated", desc = True).execute().data


def matched_experiments(supabase: Client, filters: list[Filter]) -> tuple[list[dict], int]:
    experiments = load_experiments(supabase)
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
    select: list[str] = Field(default_factory = list, exclude = True)
    filters: list[Annotated[Filter, Field(discriminator = "type")]] = Field(default_factory = list, exclude = True)
    limit: int = Field(default = 25, exclude = True)
    offset: int = Field(default = 0, exclude = True)
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

    def parse_limit(self, line: str) -> int:
        text = line.split(":", 1)[1]
        value = int(text.strip())

        if value < 1:
            raise ValueError(f"limit must be between 1 and 25, got {value}")
        if value > 25:
            raise ValueError(f"limit must be between 1 and 25, got {value}")

        return value

    def parse_offset(self, line: str) -> int:
        text = line.split(":", 1)[1]
        value = int(text.strip())

        if value < 0:
            raise ValueError(f"offset must be >= 0, got {value}")

        return value

    def parse(self) -> None:
        self.select = []
        self.filters = []
        self.limit = 25
        self.offset = 0
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

            if stripped.startswith("limit:"):
                self.limit = self.parse_limit(stripped)
                section = None
                continue

            if stripped.startswith("offset:"):
                self.offset = self.parse_offset(stripped)
                section = None
                continue

            if section == "select":
                if stripped == "id":
                    raise ValueError("`id` cannot be selected; each value is annotated with its experiment id in parentheses")
                self.select.append(stripped)
            elif section == "filters":
                parsed_filter = self.parse_filter(stripped)
                if parsed_filter.path == "id":
                    raise ValueError("`id` cannot be filtered")
                self.filters.append(parsed_filter)
            else:
                raise ValueError(f"Line outside any section: {stripped}")

        if len(self.select) == 0:
            raise ValueError("Query must select at least one path")

    def run(self, supabase: Client) -> None:
        self.parse()
        matched, base_skipped = matched_experiments(supabase, self.filters)
        limited = matched[self.offset: self.offset + self.limit]
        results: list[QueryResults] = []

        for path in self.select:
            values: list[bool | float | str] = []
            ids: list[int] = []
            skipped = base_skipped

            for experiment in limited:
                try:
                    value = resolve_path(experiment, path)
                except MissingKeyError:
                    skipped += 1
                    continue

                if isinstance(value, float) and not math.isfinite(value):
                    skipped += 1
                    continue

                values.append(value)
                ids.append(experiment["id"])

            result = QueryResults(
                path = path,
                values = values,
                ids = ids,
                skipped = skipped
            )
            results.append(result)

        self.results = results
