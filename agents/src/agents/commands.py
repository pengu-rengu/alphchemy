from agents.state import AgentsState, personal_output, global_output, get_agent_id
from pydantic import BaseModel, ValidationInfo, Field, field_validator
from typing import Annotated, Literal
from agents.format import format_hypotheses, format_papers, format_pages
from agents.arxiv import recent_arxiv, pdf_text
from ontology.updater import OntologyUpdater
from openrouter import OpenRouter
import random
import json
import redis

def execute_script(script: str, redis_client: redis.Redis):
    start_marker = "```python"
    start_idx = script.index(start_marker) + len(start_marker)
    end_idx = script.index("```", start_idx)
    script = script[start_idx:end_idx]

    funcs = {}

    exec(script, funcs)

    experiments = funcs["generate_experiments"]()

    return

    for experiment in experiments:
        experiment_data = json.dumps(experiment)
        redis_client.lpush("experiments", experiment_data)

class CommandConstraints(BaseModel):
    max_traversal_count: Annotated[int, Field(ge = 1)]
    max_arxiv_count: Annotated[int, Field(ge = 1)]
    max_pages_count: Annotated[int, Field(ge = 1)]

class ProposeExperimentsCommand(BaseModel):
    command: Literal["propose_experiments"]
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

        n_agents = len(state["agent_order"])

        if n_agents == 1:
            personal_output(state, new_state, "[ERROR] `propose` is not a valid command in single-agent mode. Use `submit` instead.\n\n")
            return

        if state["experiments_running"]:
            personal_output(state, new_state, "[ERROR] Cannot propose while experiments are already running.\n\n")
            return

        if state["proposal"]:
            personal_output(state, new_state, "[ERROR] Cannot propose while voting is in session.\n\n")
            return
        
        agent_id = get_agent_id(state)

        new_state["proposal"] = self.code
        new_state["proposal_agent"] = agent_id
        new_state["votes"] = [agent_id]

class SubmitExperimentsCommand(BaseModel):
    command: Literal["submit_experiments"]
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
    
    def run(self, state: AgentsState, new_state: AgentsState, redis_client: redis.Redis):
        n_agents = len(state["agent_order"])

        if n_agents > 1:
            personal_output(state, new_state, "[ERROR] `submit` is not a valid command in multi-agent mode.\n\n")
            return

        if state["experiments_running"]:
            personal_output(state, new_state, "[ERROR] Cannot submit while experiments are already running.\n\n")
            return

        personal_output(state, new_state, "[SUBMISSION] Running experiment generation script.\n\n")

        try:

            execute_script(self.code, redis_client)
            
        except Exception as error:
            personal_output(state, new_state, f"[ERROR] Error occurred when executing: {error}\n\n")

        new_state["experiments_running"] = True

        return new_state
    
class ProposeReportCommand(BaseModel):
    command: Literal["propose_report"]
    content: str

    def run(self, state: AgentsState, new_state: AgentsState):
        n_agents = len(state["agent_order"])

        if n_agents == 1:
            personal_output(state, new_state, "[ERROR] `propose_report` is not a valid command in single-agent mode. Use `submit_report` instead.\n\n")
            return
        
        if state["proposal"]:
            personal_output(state, new_state, "[ERROR] Cannot propose while voting is in session.\n\n")
            return
        
        agent_id = get_agent_id(state)

        new_state["proposal"] = self.content
        new_state["proposal_agent"] = agent_id
        new_state["votes"] = [agent_id]

class SubmitReportCommand(BaseModel):
    command: Literal["submit_report"]
    content: str

    def run(self, state: AgentsState, new_state: AgentsState):
        n_agents = len(state["agent_order"])

        if n_agents > 1:
            personal_output(state, new_state, "[ERROR] `submit_report` is not a valid command in multi-agent mode.\n\n")
            return

        new_state["report"] = self.content

class VoteCommand(BaseModel):
    command: Literal["vote"]

    def run(self, state: AgentsState, new_state: AgentsState):
        n_agents = len(state["agent_order"])

        if n_agents == 1:
            personal_output(state, new_state, "[ERROR] `vote` is not a valid command in single-agent mode.\n\n")
            return

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
        n_agents = len(state["agent_order"])

        if n_agents == 1:
            personal_output(state, new_state, "[ERROR] `message` is not a valid command in single-agent mode.\n\n")
            return

        agent_id = get_agent_id(state)

        global_output(state, new_state, f"[{agent_id}] {self.content}\n\n")

class TraverseCommand(BaseModel):
    command: Literal["traverse"]
    hyp_id: int
    algorithm: Literal["bfs", "dfs"]
    max_count: int

    @field_validator("hyp_id")
    @classmethod
    def validate_hyp_id(cls, hyp_id: int):
        if hyp_id == 0:
            raise ValueError("Hypothesis ID cannot be 0")
        
        return hyp_id
    
    @field_validator("max_count")
    @classmethod
    def validate_max_count(cls, max_count: int, info: ValidationInfo):
        if max_count <= 0:
            raise ValueError("Max count cannot be <= 0")
        
        if max_count > info.context.max_traversal_count:
            raise ValueError(f"Max count cannot be >= {info.context.max_traversal_count}")
        
        return max_count

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

        with open("../data/experiments.jsonl", "r") as file:
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
    max_count: int

    @field_validator("max_count")
    @classmethod
    def validate_max_count(cls, max_count: int, info: ValidationInfo):
        if max_count <= 0:
            raise ValueError("Max count cannot be <= 0")
        
        if max_count > info.context.max_arxiv_count:
            raise ValueError(f"Max count cannot be > {info.context.max_arxiv_count}")
        
        return max_count

    def run(self, state: AgentsState, new_state: AgentsState):
        papers = recent_arxiv(self.category.lower(), self.max_count)
        papers_str = format_papers(papers)

        personal_output(state, new_state, f"[ARXIV]\n{papers_str}")

class ArxivTextCommand(BaseModel):
    command: Literal["arxiv_text"]
    paper_id: str
    max_pages: int

    @field_validator("max_pages")
    @classmethod
    def validate_max_pages(cls, max_pages: int, info: ValidationInfo):
        if max_pages <= 0:
            raise ValueError("Max pages cannot be <= 0")
        
        if max_pages > info.context.max_pages_count:
            raise ValueError(f"Max pages cannot be > {info.context.max_pages_count}")
        
        return max_pages

    def run(self, state: AgentsState, new_state: AgentsState):
        pages = pdf_text(self.paper_id, self.max_pages)
        pages_str = format_pages(pages)
        
        personal_output(state, new_state, f"[PAGES]\n{pages_str}")

class SubagentCommand(BaseModel):
    command: Literal["subagent"]
    task: str
    n_agents: Annotated[int, Field(ge = 1, le = 2)]

    def run(self, state: AgentsState, new_state: AgentsState, updater: OntologyUpdater, open_router: OpenRouter, redis_client: redis.Redis):
        from agents.agent_system import AgentSystem, Agent

        models = ["deepseek/deepseek-v3.2", "moonshotai/kimi-k2.5", "qwen/qwen3.5-plus-02-15"]
        agents = [
            Agent(
                id = f"Subagent",
                plan_freq = 10,
                max_context_len = 10,
                n_delete = 3,
                chat_models = models,
                plan_models = ["openai/gpt-5.2"],
                summarize_models = models,
                command_constraints = CommandConstraints(max_traversal_count=5, max_arxiv_count=5, max_pages_count=5),
            )
        ]

        sub_system = AgentSystem(agents = agents)
        sub_system.build_graph(updater, open_router, redis_client)
        report = sub_system.run_task(self.task)

        personal_output(state, new_state, f"[SUBAGENT REPORT]\n{report}\n\n")

Command = Annotated[ProposeExperimentsCommand | SubmitExperimentsCommand | ProposeReportCommand | SubmitReportCommand | SubagentCommand | VoteCommand | MessageCommand | TraverseCommand | ExampleCommand | RecentArxivCommand | ArxivTextCommand, Field(discriminator = "command")]
