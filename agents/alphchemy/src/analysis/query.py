from __future__ import annotations

from analysis.path import resolve_path, MissingKeyError
from analysis.filters import Filter, NumericFilter, StrFilter, BoolFilter, matches_filters
from typing import Annotated, TYPE_CHECKING
from pydantic import BaseModel, Field
import math

if TYPE_CHECKING:
    from supabase import Client


class QueryResults(BaseModel):
    path: str
    values: list[bool | float | str]
    skipped: int


def load_experiments(supabase: Client) -> list[dict]:
    table = supabase.table("experiments")
    selected = table.select("id, title, experiment, results, status")
    return selected.eq("status", "completed").execute().data


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

    def build_filter(self, path: str, operator: str, value_text: str) -> Filter:
        if value_text.startswith("\""):
            if operator != "==":
                raise ValueError(f"String filter only supports ==, got {operator}")

            text = value_text.strip("\"")
            return StrFilter(path = path, eq = text)

        if value_text == "true" or value_text == "false":
            if operator != "==":
                raise ValueError(f"Bool filter only supports ==, got {operator}")

            flag = value_text == "true"
            return BoolFilter(path = path, eq = flag)

        number = float(value_text)
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

    def parse(self) -> None:
        self.select = []
        self.filters = []
        self.limit = 25
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

            if section == "select":
                self.select.append(stripped)
            elif section == "filters":
                parsed_filter = self.parse_filter(stripped)
                self.filters.append(parsed_filter)
            else:
                raise ValueError(f"Line outside any section: {stripped}")

        if len(self.select) == 0:
            raise ValueError("Query must select at least one path")

    def run(self, supabase: Client) -> None:
        self.parse()
        matched, base_skipped = matched_experiments(supabase, self.filters)
        limited = matched[:self.limit]
        results: list[QueryResults] = []

        for path in self.select:
            values: list[bool | float | str] = []
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

            result = QueryResults(
                path = path,
                values = values,
                skipped = skipped
            )
            results.append(result)

        self.results = results
