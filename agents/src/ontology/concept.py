import pandas as pd
import numpy as np
import heapq
from dataclasses import dataclass, field
from typing import Annotated
from pydantic import BaseModel, Field

@dataclass
class Concept:
    id: int
    upper_bounds: dict[str, float] = field(default_factory = dict)
    lower_bounds: dict[str, float] = field(default_factory = dict)
    ids: list[int] = field(default_factory = list)

    def set_ids(self, df: pd.DataFrame):
        if df.empty:
            return

        in_concept = pd.Series(True, index = df.index)

        for col, upper in self.upper_bounds.items():
            in_concept &= (df[col] >= self.lower_bounds[col]) & (df[col] <= upper)

        self.ids = df.loc[in_concept, "id"].tolist()

def parse_concepts(concepts_json: list[dict]) -> list[Concept]:
    concepts = []

    for concept_json in concepts_json:
        concept = Concept(
            id = concept_json["id"],
            upper_bounds = concept_json["upper_bounds"],
            lower_bounds = concept_json["lower_bounds"],
            ids = concept_json["ids"]
        )
        concepts.append(concept)

    return concepts

class ConceptFactory(BaseModel):

    max_cols: Annotated[int, Field(ge = 1)]
    coverage_threshold: Annotated[float, Field(ge = 0.0, le = 1.0)]
    activation_threshold: Annotated[float, Field(ge = 0.0)]

    def make_concept(self, concept_df: pd.DataFrame, experiments_df: pd.DataFrame, id: int) -> Concept:

        bounds = []

        for col in concept_df.columns:
            if col == "id":
                continue

            concept_min = concept_df[col].min()
            concept_max = concept_df[col].max()

            global_min = experiments_df[col].min()
            global_max = experiments_df[col].max()

            concept_range = concept_max - concept_min
            global_range = global_max - global_min

            if concept_range == 0 or global_range == 0:
                continue

            coverage = concept_range / global_range

            if coverage > self.coverage_threshold:
                continue

            heapq.heappush_max(bounds, (coverage, concept_min, concept_max, col))
            if len(bounds) > self.max_cols:
                heapq.heappop_max(bounds)

        concept = Concept(id = id)

        for _, concept_min, concept_max, col in bounds:
            concept.upper_bounds[col] = concept_max
            concept.lower_bounds[col] = concept_min

        concept.set_ids(experiments_df)

        return concept

    def make_concepts(self, latent: np.ndarray, experiments_df: pd.DataFrame) -> list[Concept]:

        concepts = []

        n_features = latent.shape[1]

        for feature_idx in range(n_features):

            print(f"Making concept for feature {feature_idx + 1}/{n_features}")

            active_mask = latent[:, feature_idx] > self.activation_threshold

            if not np.any(active_mask):
                continue

            concept_df = experiments_df[active_mask].copy()

            concept = self.make_concept(concept_df, experiments_df, feature_idx)
            concepts.append(concept)

        return concepts
