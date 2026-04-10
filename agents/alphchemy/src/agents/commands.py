from agents.state import AgentsState, personal_output, global_output, get_agent_id
from analysis.filters import Filter
from analysis.query import query_experiments
from pydantic import BaseModel, Field
from typing import Annotated, Literal, TYPE_CHECKING
from openrouter import OpenRouter
from collections import defaultdict
import random
import json

if TYPE_CHECKING:
    from agents.agent_system import Agent

def announce_proposal(state: AgentsState, new_state: AgentsState, agent_id: str, proposal: str, subject: str) -> None:
    global_output(state, new_state, f"[PROPOSAL] {agent_id} has proposed {subject}. Voting is now in session.\n", ignore_current = False)
    global_output(state, new_state, f"{proposal}\n\n", ignore_current = False)


def require_main_agent(state: AgentsState, new_state: AgentsState, command_name: str) -> bool:
    if not state["is_subagent"]:
        return True

    personal_output(state, new_state, f"[ERROR] `{command_name}` is not available for subagents.\n\n")
    return False


def require_multi_agent(state: AgentsState, new_state: AgentsState, command_name: str, fallback_name: str | None = None) -> bool:
    n_agents = len(state["agent_order"])

    if n_agents > 1:
        return True

    suffix = f" Use `{fallback_name}` instead." if fallback_name else ""
    personal_output(state, new_state, f"[ERROR] `{command_name}` is not a valid command in single-agent mode.{suffix}\n\n")
    return False


def require_single_agent(state: AgentsState, new_state: AgentsState, command_name: str) -> bool:
    n_agents = len(state["agent_order"])

    if n_agents == 1:
        return True

    personal_output(state, new_state, f"[ERROR] `{command_name}` is not a valid command in multi-agent mode.\n\n")
    return False


def require_no_active_proposal(state: AgentsState, new_state: AgentsState) -> bool:
    if state["proposal_state"]["state"] != "proposal":
        return True

    personal_output(state, new_state, "[ERROR] Cannot propose while voting is in session.\n\n")
    return False


class ExperimentsCommand(BaseModel):
    generator: dict
    param_space: dict
    
    def payload(self) -> dict[str, object]:
        return {
            "generator": self.generator,
            "param_space": self.param_space
        }


class ProposeExperimentsCommand(ExperimentsCommand):
    command: Literal["propose_experiments"]

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_main_agent(state, new_state, self.command):
            return

        if not require_multi_agent(state, new_state, self.command, "submit_experiments"):
            return

        if not require_no_active_proposal(state, new_state):
            return

        agent_id = get_agent_id(state)
        proposal = self.payload()
        new_state["proposal_state"] = {
            "state": "proposal",
            "type": "generator",
            "proposal": proposal,
            "agent_id": agent_id,
            "votes": [agent_id]
        }

        proposal_str = json.dumps(proposal, indent = 2)
        announce_proposal(state, new_state, agent_id, proposal_str, "an experiment generator")

class SubmitExperimentsCommand(ExperimentsCommand):
    command: Literal["submit_experiments"]

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_main_agent(state, new_state, self.command):
            return

        if not require_single_agent(state, new_state, self.command):
            return
        
        new_state["proposal_state"] = {
            "state": "submission",
            "type": "generator",
            "submission": self.payload()
        }
    
class ProposeReportCommand(BaseModel):
    command: Literal["propose_report"]
    report: str

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_multi_agent(state, new_state, self.command, "submit_report"):
            return

        if not require_no_active_proposal(state, new_state):
            return

        agent_id = get_agent_id(state)

        announce_proposal(state, new_state, agent_id, self.report, "a report")
        new_state["proposal_state"] = {
            "state": "proposal",
            "type": "report",
            "proposal": {
                "report": self.report
            },
            "agent_id": agent_id,
            "votes": [agent_id]
        }

class SubmitReportCommand(BaseModel):
    command: Literal["submit_report"]
    report: str

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_single_agent(state, new_state, self.command):
            return

        new_state["proposal_state"] = {
            "state": "submission",
            "type": "report",
            "submission": {
                "report": self.report
            }
        }


class VoteCommand(BaseModel):
    command: Literal["vote"]

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_multi_agent(state, new_state, "vote"):
            return

        agent_id = get_agent_id(state)

        proposal_state = state["proposal_state"]

        if proposal_state["state"] != "proposal":
            personal_output(state, new_state, f"[ERROR] Voting is not in session.\n\n")
            return

        if agent_id in proposal_state["votes"]:
            personal_output(state, new_state, "[ERROR] You have already voted.\n\n")
            return

        global_output(state, new_state, f"[VOTE] {agent_id} has voted in favor of the proposal.\n\n", ignore_current = False)
        new_state["proposal_state"] = {
            "state": "proposal",
            "type": proposal_state["type"],
            "proposal": proposal_state["proposal"],
            "agent_id": proposal_state["agent_id"],
            "votes": proposal_state["votes"] + [agent_id]
        }
        

class MessageCommand(BaseModel):
    command: Literal["message"]
    content: Annotated[str, Field(min_length = 1)]

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_multi_agent(state, new_state, "message"):
            return

        agent_id = get_agent_id(state)

        global_output(state, new_state, f"[{agent_id}] {self.content}\n\n")

class SubagentCommand(BaseModel):
    command: Literal["subagent"]
    prompt: str
    n_agents: Annotated[int, Field(ge = 1, le = 2)]

    def select_templates(self, subagent_pool: list["Agent"], n_agents: int) -> list["Agent"]:
        
        if n_agents <= len(subagent_pool):
            return random.sample(subagent_pool, n_agents)

        selected_templates = []

        for _ in range(n_agents):
            random_subagent = random.choice(subagent_pool)
            selected_templates.append(random_subagent)

        return selected_templates

    def clone_templates(self, selected_templates: list["Agent"]) -> list["Agent"]:
        clone_counts = defaultdict(int)
        cloned_agents = []

        for template in selected_templates:
            template_id = template.id
            clone_counts[template_id] += 1
            current_count = clone_counts[template_id]

            runtime_id = template_id

            if current_count > 1:
                runtime_id = f"{template_id}-{current_count}"

            cloned_agent = template.model_copy(deep = True, update = {"id": runtime_id})
            cloned_agents.append(cloned_agent)

        return cloned_agents

    def run(self, state: AgentsState, new_state: AgentsState, subagent_pool: list["Agent"], open_router: OpenRouter) -> None:
        from agents.agent_system import AgentSystem

        if state["is_subagent"]:
            personal_output(state, new_state, "[ERROR] `subagent` is not a valid command for subagents.\n\n")
            return

        pool_size = len(subagent_pool)

        if pool_size == 0:
            personal_output(state, new_state, "[ERROR] No subagent configurations available.\n\n")
            return

        selected_templates = self.select_templates(subagent_pool, self.n_agents)
        selected = self.clone_templates(selected_templates)

        sub_system = AgentSystem(agents = selected)
        sub_system.build_graph(open_router)
        report = sub_system.run(None, self.prompt, is_subagent = True)["submission"]["report"]

        personal_output(state, new_state, f"[SUBAGENT REPORT]\n{report}\n\n")


class AnalyzeDataCommand(BaseModel):
    command: Literal["analyze_data"]
    select: Annotated[
        list[Annotated[str, Field(min_length = 1)]],
        Field(min_length = 1)
    ]
    filters: list[list[Filter]] = Field(default_factory = list)

    def run(self, state: AgentsState, new_state: AgentsState) -> None:
        try:
            result = query_experiments(
                select = self.select,
                filter_groups = self.filters
            )
            personal_output(state, new_state, result)
        except FileNotFoundError:
            personal_output(state, new_state, "[ERROR] Could not find experiments data.\n\n")
        except Exception as error:
            personal_output(state, new_state, f"[ERROR] {error}\n\n")

Command = Annotated[ProposeExperimentsCommand | SubmitExperimentsCommand | ProposeReportCommand | SubmitReportCommand | SubagentCommand | VoteCommand | MessageCommand | AnalyzeDataCommand, Field(discriminator = "command")]
