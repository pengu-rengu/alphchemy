from __future__ import annotations

from analysis.path import resolve_path
from analysis.filters import Filter, matches_filters
from typing import Annotated, TYPE_CHECKING
from pydantic import BaseModel, Field
import pandas as pd

if TYPE_CHECKING:
    from supabase import Client

class SelectResults(BaseModel):
    min_: float = Field(serialization_alias = "min")
    q1: float
    median: float
    q3: float
    max_: float = Field(serialization_alias = "max")

    model_config = {"populate_by_name": True}


def load_experiments(supabase: Client) -> list[dict]:
    table = supabase.table("experiments")
    selected = table.select("id, experiment, results, status")
    rows = selected.eq("status", "completed").execute().data
    experiments: list[dict] = []

    for row in rows:
        try:
            data = {"experiment": row["experiment"], "results": row["results"], "id": row["id"]}
            experiments.append(data)
        except:
            print("failed to parse row:", row)

    return experiments


def matched_experiments(supabase: Client, filters: list[Filter]) -> list[dict]:
    experiments = load_experiments(supabase)
    groups = [filters] if len(filters) > 0 else []
    matched = []

    for experiment in experiments:
        if matches_filters(experiment, groups):
            matched.append(experiment)

    return matched


class SelectQuery(BaseModel):
    select: list[str]
    filters: list[Annotated[Filter, Field(discriminator = "type")]]
    results: None | list[SelectResults] = None

    def run(self, supabase: Client) -> None:
        matched = matched_experiments(supabase, self.filters)

        if len(matched) == 0:
            self.results = []
            return

        results: list[SelectResults] = []

        for path in self.select:
            values = [resolve_path(experiment, path) for experiment in matched]
            series = pd.Series(values, dtype = "float64")
            quantiles = series.quantile([0.0, 0.25, 0.5, 0.75, 1.0])
            result = SelectResults(
                min_ = float(quantiles.loc[0.0]),
                q1 = float(quantiles.loc[0.25]),
                median = float(quantiles.loc[0.5]),
                q3 = float(quantiles.loc[0.75]),
                max_ = float(quantiles.loc[1.0])
            )
            results.append(result)

        self.results = results


class SearchQuery(BaseModel):
    filters: list[Annotated[Filter, Field(discriminator = "type")]]
    results: None | list[int] = None

    def run(self, supabase: Client) -> None:
        matched = matched_experiments(supabase, self.filters)
        self.results = [experiment["id"] for experiment in matched]
