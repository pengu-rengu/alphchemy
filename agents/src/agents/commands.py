from agents.state import AgentsState, personal_output, global_output, get_agent_id
from pydantic import BaseModel, ValidationInfo, Field, field_validator
from typing import Annotated, Literal
from agents.format import format_hypotheses, format_papers, format_pages
from ontology.updater import OntologyUpdater
from generator.generators import ExperimentGen
from generator.params import ParamSpace
from openrouter import OpenRouter
import random
import json
import redis


def execute_generator(generator_json: dict, search_space: dict, redis_client: redis.Redis) -> None:
    experiment_gen = ExperimentGen.model_validate(generator_json)
    param_space = ParamSpace(search_space=search_space)
    experiments = param_space.generate_experiments(experiment_gen, 1000)

    for experiment in experiments:
        serialized = json.dumps(experiment)
        redis_client.lpush("experiments", serialized)

class CommandConstraints(BaseModel):
    max_traversal_count: Annotated[int, Field(ge = 1)]

class ProposeExperimentsCommand(BaseModel):
    command: Literal["propose_experiments"]
    generator: dict
    search_space: dict[str, list]

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

        proposal_data = json.dumps({
            "generator": self.generator,
            "search_space": self.search_space
        })
        new_state["proposal"] = proposal_data
        new_state["proposal_agent"] = agent_id
        new_state["votes"] = [agent_id]

class SubmitExperimentsCommand(BaseModel):
    command: Literal["submit_experiments"]
    generator: dict
    search_space: dict[str, list]

    def run(self, state: AgentsState, new_state: AgentsState, redis_client: redis.Redis):
        n_agents = len(state["agent_order"])

        if n_agents > 1:
            personal_output(state, new_state, "[ERROR] `submit` is not a valid command in multi-agent mode.\n\n")
            return

        if state["experiments_running"]:
            personal_output(state, new_state, "[ERROR] Cannot submit while experiments are already running.\n\n")
            return

        personal_output(state, new_state, "[SUBMISSION] Running experiment generation.\n\n")

        try:
            execute_generator(self.generator, self.search_space, redis_client)
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

class SubagentCommand(BaseModel):
    command: Literal["subagent"]
    task: str
    n_agents: Annotated[int, Field(ge = 1, le = 2)]

    def run(self, state: AgentsState, new_state: AgentsState, subagent_pool: list, updater: OntologyUpdater, open_router: OpenRouter, redis_client: redis.Redis):
        from agents.agent_system import AgentSystem

        pool_size = len(subagent_pool)

        if pool_size == 0:
            personal_output(state, new_state, "[ERROR] No subagent configurations available.\n\n")
            return

        if self.n_agents <= pool_size:
            selected = random.sample(subagent_pool, self.n_agents)
        else:
            selected = random.choices(subagent_pool, k = self.n_agents)

        sub_system = AgentSystem(agents = selected)
        sub_system.build_graph(updater, open_router, redis_client)
        report = sub_system.run_task(self.task)

        personal_output(state, new_state, f"[SUBAGENT REPORT]\n{report}\n\n")

Command = Annotated[ProposeExperimentsCommand | SubmitExperimentsCommand | ProposeReportCommand | SubmitReportCommand | SubagentCommand | VoteCommand | MessageCommand | TraverseCommand | ExampleCommand, Field(discriminator = "command")]
