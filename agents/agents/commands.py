from agents.state import AgentsState, personal_output, global_output, get_agent_id
from pydantic import BaseModel, Field, field_validator
from typing import Annotated, Literal
from agents.format import format_hypotheses, format_papers, format_pages
from agents.arxiv import recent_arxiv, pdf_text
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
        traversal_str = format_hypotheses(traversal, ontology.result_metric)

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

class RecentArxivCommand(BaseModel):
    command: Literal["recent_arxiv"]
    category: str
    max_count: Annotated[int, Field(ge = 1, le = 10)]

    def run(self, state: AgentsState, new_state: AgentsState):
        papers = recent_arxiv(self.category, self.max_count)
        papers_str = format_papers(papers)

        personal_output(state, new_state, f"[ARXIV]\n{papers_str}")

class ArxivTextCommand(BaseModel):
    command: Literal["arxiv_text"]
    paper_id: str
    max_pages: Annotated[int, Field(ge = 1, le = 5)]

    def run(self, state: AgentsState, new_state: AgentsState):
        pages = pdf_text(self.paper_id, self.max_pages)
        pages_str = format_pages(pages)
        
        personal_output(state, new_state, f"[PAGES]\n{pages_str}")

Command = Annotated[ProposeCommand | VoteCommand | MessageCommand | TraverseCommand | ExampleCommand | RecentArxivCommand | ArxivTextCommand, Field(discriminator = "command")]
