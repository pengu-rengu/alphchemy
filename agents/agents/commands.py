from agents.state import AgentsState, personal_output, global_output, get_agent_id
from pydantic import BaseModel, Field, field_validator
from typing import Annotated, Literal
from ontology.concept import HyperRect
from ontology.ontology import Ontology, Hypothesis
from ontology.updater import OntologyUpdater
import random

class ProposeCommand(BaseModel):
    command: Literal["propose"]
    code: str

    @field_validator("code")
    @classmethod
    def validate_code(cls, code: str):
        if not code.startswith("```python"):
            raise ValueError("Code must start with '```python'")
        
        if not code.endswith("```"):
            raise ValueError("Code must end with '```'")
        
        if not "def generate_experiments():" in code:
            raise ValueError("Code must contain 'def generate_experiments():' function")
        
        return code
    
    def run(self, state: AgentsState, new_state: AgentsState):

        if state["experiments_running"]:
            personal_output(state, new_state, "[ERROR] Cannot propose while experiments are already running.\n\n")
            return

        if state["proposal"]:
            personal_output(state, new_state, "[ERROR] Cannot propose while voting is in session.\n\n")
            return

        params = state["params"][0]
        agent_id = get_agent_id(state)

        new_state["proposal"] = self.code
        new_state["proposal_agent"] = agent_id
        new_state["votes"] = [agent_id]

        global_output(state, new_state, f"[PROPOSAL] {agent_id} has proposed a generation script. Voting is now in session.\n", ignore_current = False)
        global_output(state, new_state, f"{new_state['proposal']}\n\n")

class VoteCommand(BaseModel):
    command: Literal["vote"]

    def run(self, state: AgentsState, new_state: AgentsState):
        agent_id = get_agent_id(state)

        if not state["proposal"]:
            personal_output(state, new_state, f"[ERROR] Voting is not in session.\n\n")
            return

        if agent_id in state["votes"]:
            personal_output(state, new_state, "[ERROR] You have already voted.\n\n")
            return

        global_output(state, new_state, f"[VOTE] {agent_id} has voted in favor of the proposal.\n\n", ignore_current = False)
        new_state["votes"] = [agent_id]

class MessageCommand(BaseModel):
    command: Literal["message"]
    content: Annotated[str, Field(min_length = 1)]

    def run(self, state: AgentsState, new_state: AgentsState):
        agent_id = get_agent_id(state)

        global_output(state, new_state, f"[{agent_id}] {self.content}\n\n")

class TraverseCommand(BaseModel):
    command: Literal["traverse"]
    hyp_id: int
    algorithm: Literal["bfs", "dfs"]
    max_count: Annotated[int, Field(ge = 1, le = 10)]

    @field_validator("hyp_id")
    @classmethod
    def validate_hyp_id(cls, hyp_id):
        if hyp_id == 0:
            raise ValueError("Hypothesis ID cannot be 0")
        
        return hyp_id

    def format_hyper_rect(self, rect: HyperRect) -> str:
        
        upper_bounds = rect.upper_bounds

        rules = [f"{rect.lower_bounds[col]} <= {col} <= {upper_bounds[col]}" for col in upper_bounds]
        
        return f"({' AND '.join(rules)})"

    def format_concept(self, hyp: Hypothesis, result_metric: str) -> str:
        rules = [self.format_hyper_rect(hyper_rect) for hyper_rect in hyp.concept.rects]

        text = f"\tExperiments that satisfy the following conditions\n"
        text += f"\t({' OR '.join(rules)})\n"
        text += f"\thave a {'higher' if hyp.effect_size > 0 else 'lower'} {result_metric} than experiments that do not satisfy the conditions.\n\n"

        return text

    def format_entries(self, entries: str, n_other: int) -> str:
        if entries:
            text = entries
            if n_other:
                text += f"\t\tAnd {n_other} other hypotheses\n\n"
        elif n_other:
            text = f"\t\t{n_other} hypotheses\n\n"
        else:
            text = "\t\tNothing\n\n"
        
        return text

    def format_edges(self, hyp: Hypothesis, hyp_ids: set[int]) -> str:
        validates = ""
        invalidates = ""

        n_other_validates = 0
        n_other_invalidates = 0
        count = 0

        for edge in hyp.edges:
            other_hyp = edge.neighbor(hyp)

            if other_hyp.id not in hyp_ids:
                n_other_validates += edge.validates
                n_other_invalidates += not edge.validates
                continue
            
            entry = f"\t\tHypothesis ID: {other_hyp.id}\n"
            entry += f"\t\tJaccard Similarity: {edge.jaccard}\n\n"

            count += 1

            if edge.validates:
                validates += entry
            else:
                invalidates += entry

        text = f"\tValidates:\n\n{self.format_entries(validates, n_other_validates)}"
        text += f"\tInvalidates:\n\n{self.format_entries(invalidates, n_other_invalidates)}"

        return text

    def format_hypotheses(self, hyps: list[Hypothesis], result_metric: str) -> str:

        hyp_ids = set([hyp.id for hyp in hyps])
        
        text = ""

        for hyp in hyps:

            text += f"Hypothesis ID: {hyp.id}\n\n"
            text += self.format_concept(hyp, result_metric)
            text += self.format_edges(hyp, hyp_ids)
            
            text += "\tStatistics:\n"
            text += f"\t\tEffect Size: {hyp.effect_size}\n"
            text += f"\t\tP-Value: {hyp.p_value}\n\n"

        return text

    def format_traversal(self, ontology: Ontology, hyp_id: int, algorithm: str, max_count: int) -> str:
        focal_hyp = next((h for h in ontology.hypotheses if h.id == hyp_id), None)
        if not focal_hyp:
            return f"Hypothesis {hyp_id} not found."

        hyps = ontology.traverse(focal_hyp, algorithm, max_count)
        
        return self.format_hypotheses(hyps, ontology.result_metric)

    def run(self, state: AgentsState, new_state: AgentsState, updater: OntologyUpdater):
        
        ontology = updater.ontology
        hyps = ontology.hypotheses

        if self.hyp_id < 0:
            focal_hyp = random.choice(hyps)
        else:
            focal_hyp = next((h for h in hyps if h.id == self.hyp_id), None)

        if not focal_hyp:
            personal_output(state, new_state, f"[ERROR] Hypothesis {self.hyp_id} not found.\n\n")
            return

        traversal = ontology.traverse(focal_hyp, self.algorithm, self.max_count)
        traversal_str = self.format_hypotheses(traversal, ontology.result_metric)

        personal_output(state, new_state, f"[TRAVERSAL]\n{traversal_str}")

class ExampleCommand(BaseModel):
    command: Literal["example"]
    hyp_id: int

    def run(self, state: AgentsState, new_state: AgentsState, updater: OntologyUpdater):

        hyp = next((h for h in updater.ontology.hypotheses if h.id == self.hyp_id), None)

        if not hyp:
            personal_output(state, new_state, f"[ERROR] Hypothesis {self.hyp_id} not found.\n\n")
            return
        
        experiment_id = random.choice(hyp.concept.ids)

        example = ""

        with open("data/experiments.jsonl", "r") as file:
            for id, line in enumerate(file):
                if id == experiment_id:
                    example += f"{line}\n\n"
                    break

        if not example:
            personal_output(state, new_state, "[ERROR] Could not find example.\n\n")
            return
        
        personal_output(state, new_state, f"[EXAMPLE]\n\n{example}\n\n")

Command = Annotated[ProposeCommand | VoteCommand | MessageCommand | TraverseCommand | ExampleCommand, Field(discriminator = "command")]
