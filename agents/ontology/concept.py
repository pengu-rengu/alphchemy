import pandas as pd
import numpy as np
import heapq
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import silhouette_score
from dataclasses import dataclass, field

@dataclass
class HyperRect:
    upper_bounds: dict[str, float] = field(default_factory = dict)
    lower_bounds: dict[str, float] = field(default_factory = dict)

@dataclass
class Concept:
    id: int
    rects: list[HyperRect]
    ids: list[int] = field(default_factory = list)

    def set_ids(self, df: pd.DataFrame):
        if df.empty:
            return

        in_concept = pd.Series(False, index = df.index)

        for rect in self.rects:
            in_rect = pd.Series(True, index = df.index)

            for col, upper in rect.upper_bounds.items():

                in_rect &= (df[col] >= rect.lower_bounds[col]) & (df[col] <= upper)
            
            in_concept |= in_rect

        self.ids = df.loc[in_concept, "id"].tolist()

def parse_concepts(concepts_json: list[dict]) -> list[Concept]:
    concepts = []

    for concept_json in concepts_json:

        rects = []

        for rect_json in concept_json["rects"]:
            rect = HyperRect(
                upper_bounds = rect_json["upper_bounds"],
                lower_bounds = rect_json["lower_bounds"]
            )
            rects.append(rect)
        
        concept = Concept(
            id = concept_json["id"],
            rects = rects,
            ids = concept_json["ids"]
        )
        concepts.append(concept)
    
    return concepts

@dataclass
class ConceptFactory:
    min_k: int
    max_k: int
    max_cols: int
    coverage_threshold: float
    activation_threshold: float

    def kmeans_cluster(self, concept_df: pd.DataFrame):
        scaler = StandardScaler()

        data = concept_df.drop(columns = ["id"])
        data = scaler.fit_transform(data)

        best_k = self.min_k
        best_score = -1

        for k in range(self.min_k, self.max_k + 1):
            print(f"Making cluster for k = {k}/{self.max_k}")

            kmeans = KMeans(n_clusters = k)
            kmeans.fit(data)
            score = silhouette_score(data, kmeans.labels_)

            if score > best_score:
                best_score = score
                best_k = k

        kmeans = KMeans(n_clusters = best_k)
        concept_df["cluster"] = kmeans.fit_predict(data)

    def make_hyper_rect(self, cluster_df: pd.DataFrame, experiments_df: pd.DataFrame) -> HyperRect:

        bounds = []
        
        for col in cluster_df.columns:
            if col in ["id", "cluster"]:
                continue
            
            cluster_min = cluster_df[col].min()
            cluster_max = cluster_df[col].max()

            global_min = experiments_df[col].min()
            global_max = experiments_df[col].max()

            cluster_range = cluster_max - cluster_min
            experiments_range = global_max - global_min

            if experiments_range == 0:
                continue
            
            coverage = cluster_range / experiments_range
            
            if coverage > self.coverage_threshold:
                continue

            heapq.heappush_max(bounds, (coverage, cluster_min, cluster_max, col))
            if len(bounds) > self.max_cols:
                heapq.heappop_max(bounds)

        hyper_rect = HyperRect()

        for _, cluster_min, cluster_max, col in bounds:
            hyper_rect.upper_bounds[col] = cluster_max
            hyper_rect.lower_bounds[col] = cluster_min

        return hyper_rect

    def make_concept(self, concept_df: pd.DataFrame, experiments_df: pd.DataFrame, id: int) -> Concept:
        if len(concept_df) < self.max_k:
            concept_df["cluster"] = 1
        else:
            self.kmeans_cluster(concept_df)

        cluster_groups = concept_df.groupby("cluster")
        clusters = [self.make_hyper_rect(cluster_df, experiments_df) for _, cluster_df in cluster_groups]
        
        concept = Concept(id = id, rects = clusters)
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
    
    