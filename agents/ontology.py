import pandas as pd
import heapq
from collections import deque
from scipy import stats
from concept import Concept, parse_concepts
from dataclasses import dataclass, field, asdict

@dataclass
class Hypothesis:
    id: int
    concept: Concept
    effect_size: float
    p_value: float

    edges: list[Edge] = field(default_factory = list)

    def __lt__(self, other: Hypothesis):
        return self.effect_size < other.effect_size

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "concept_id": self.concept.id,
            "effect_size": self.effect_size,
            "p_value": self.p_value,
        }

@dataclass
class Edge:
    hyp1: Hypothesis
    hyp2: Hypothesis
    validates: bool
    jaccard: float

    def __lt__(self, other: Edge):
        return self.jaccard < other.jaccard
    
    def neighbor(self, hyp: Hypothesis) -> Hypothesis:
        return self.hyp1 if self.hyp1 != hyp else self.hyp2

    def to_json(self) -> dict:
        return {
            "hyp1_id": self.hyp1.id,
            "hyp2_id": self.hyp2.id,
            "validates": self.validates,
            "jaccard": self.jaccard,
        }
    

@dataclass
class Ontology:
    result_metric: str
    concepts: list[Concept]
    hypotheses: list[Hypothesis]
    edges: list[Edge]

    def traverse(self, focal_hyp: Hypothesis, algorithm: str, max_count: int) -> list[Hypothesis]:
        container = deque([focal_hyp])
        visited_ids = set([focal_hyp.id])

        hyps = []
        
        while container and len(hyps) < max_count:
            if algorithm == "bfs":
                current_hyp = container.popleft()
            elif algorithm == "dfs":
                current_hyp = container.pop()
            else:
                raise ValueError(f"Unknown algorithm: {algorithm}")

            hyps.append(current_hyp)
            
            for edge in current_hyp.edges:
                neighbor = edge.neighbor(current_hyp)

                if neighbor.id not in visited_ids:
                    visited_ids.add(neighbor.id)
                    container.append(neighbor)
        
        return hyps

    def to_json(self) -> dict:
        concepts_json = [asdict(concept) for concept in self.concepts]
        hyps_json = [hyp.to_json() for hyp in self.hypotheses]
        edges_json = [edge.to_json() for edge in self.edges]

        return {
            "result_metric": self.result_metric,
            "concepts": concepts_json,
            "hypotheses": hyps_json,
            "edges": edges_json
        }

def parse_hypotheses(hyps_json: list[dict], concepts: list[Concept]) -> list[Hypothesis]:
    id_to_concept = {concept.id: concept for concept in concepts}

    return [Hypothesis(
        id = hyp_json["id"],
        concept = id_to_concept[hyp_json["concept_id"]],
        effect_size = hyp_json["effect_size"],
        p_value = hyp_json["p_value"]
    ) for hyp_json in hyps_json]

def parse_edges(edges_json: list[dict], hyps: list[Hypothesis]) -> list[Edge]:
    id_to_hyp = {hyp.id: hyp for hyp in hyps}

    edges = []
    for edge_json in edges_json:

        edge = Edge(
            hyp1 = id_to_hyp[edge_json["hyp1_id"]],
            hyp2 = id_to_hyp[edge_json["hyp2_id"]],
            validates = edge_json["validates"],
            jaccard = edge_json["jaccard"]
        )
        
        edge.hyp1.edges.append(edge)
        edge.hyp2.edges.append(edge)
        edges.append(edge)
    return edges

def parse_ontology(ontology_json: dict) -> Ontology:
    concepts = parse_concepts(ontology_json["concepts"])
    hyps = parse_hypotheses(ontology_json["hypotheses"], concepts)
    edges = parse_edges(ontology_json["edges"], hyps)

    return Ontology(
        result_metric = ontology_json["result_metric"],
        concepts = concepts,
        hypotheses = hyps,
        edges = edges
    )

@dataclass
class OntologyFactory:
    result_metric: str

    significance_threshold: float
    jaccard_threshold: float

    max_hypotheses: int
    max_edges: int

    def make_hypothesis(self, concept: Concept, results_df: pd.DataFrame, id: int) -> Hypothesis:

        print(f"Making hypothesis")
        
        in_concept = results_df["id"].isin(concept.ids)
        included = results_df[in_concept]
        complement = results_df[~in_concept]

        t_stat, p_value = stats.ttest_ind(included[self.result_metric], complement[self.result_metric], equal_var = False)

        return Hypothesis(
            id = id,
            concept = concept,
            effect_size = t_stat,
            p_value = p_value
        )

    def make_hypotheses(self, concepts: list[Concept], results_df: pd.DataFrame) -> list[Hypothesis]:
        hyps = []

        count = 1

        for concept in concepts:
            
            hyp = self.make_hypothesis(concept, results_df, count + 1)
            
            if hyp.p_value < self.significance_threshold:
                count += 1
                heapq.heappush_max(hyps, hyp)

                if len(hyps) > self.max_hypotheses:
                    heapq.heappop_max(hyps)
    
        return list(hyps)
    
    def make_edge(self, hyp1: Hypothesis, hyp2: Hypothesis) -> Edge:

        validates = bool((hyp1.effect_size > 0) == (hyp2.effect_size > 0))

        hyp1_ids = set(hyp1.concept.ids)
        hyp2_ids = set(hyp2.concept.ids)
        
        n_intersect = len(hyp1_ids & hyp2_ids)
        n_union = len(hyp1_ids | hyp2_ids)

        jaccard = n_intersect / n_union if n_union > 0.0 else 0.0

        return Edge(
            hyp1 = hyp1,
            hyp2 = hyp2,
            validates = validates,
            jaccard = jaccard,
        )
    
    def make_edges(self, hypotheses: list[Hypothesis]) -> list[Edge]:

        edges = []

        for i, hyp1 in enumerate(hypotheses):
            for hyp2 in hypotheses[i + 1:]:
                print(i, len(edges), len(hypotheses))

                edge = self.make_edge(hyp1, hyp2)
                if edge.jaccard > self.jaccard_threshold:
                    heapq.heappush(edges, edge)
                    if len(edges) > self.max_edges:
                        heapq.heappop(edges)
        
        for edge in edges:
            edge.hyp1.edges.append(edge)
            edge.hyp2.edges.append(edge)
        
        return list(edges)
    
    def make_ontology(self, concepts: list[Concept], results_df: pd.DataFrame) -> Ontology:
        
        hyps = self.make_hypotheses(concepts, results_df)
        edges = self.make_edges(hyps)

        return Ontology(
            result_metric = self.result_metric,
            concepts = concepts,
            hypotheses = hyps,
            edges = edges
        )