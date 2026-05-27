from __future__ import annotations

from agents.state import AgentsState, personal_output, global_output, get_agent_id, make_initial_state, update_state
from analysis.filters import Filter
from analysis.query import SelectQuery
from analysis.format_analysis import format_select_results
from pydantic import BaseModel, Field
from typing import Annotated, Literal, TYPE_CHECKING
from openrouter import OpenRouter
from collections import defaultdict
from datetime import datetime, timezone
import random
import json


def iso_to_epoch_seconds(value: str) -> float:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo = timezone.utc)
    return parsed.timestamp()

if TYPE_CHECKING:
    from agents.agent_system import Agent
    from supabase import Client

def announce_proposal(state: AgentsState, new_state: AgentsState, agent_id: str, proposal: str, subject: str) -> None:
    content = f"{agent_id} has proposed {subject}. Voting is now in session.\n\n{proposal}"
    global_output(state, new_state, {"tag": "PROPOSAL", "content": content}, ignore_current = False)


def require_main_agent(state: AgentsState, new_state: AgentsState, command_name: str) -> bool:
    if not state["is_subagent"]:
        return True

    personal_output(state, new_state, {"tag": "ERROR", "content": f"`{command_name}` is not available for subagents."})
    return False


def require_subagent(state: AgentsState, new_state: AgentsState, command_name: str) -> bool:
    if state["is_subagent"]:
        return True

    personal_output(state, new_state, {"tag": "ERROR", "content": f"`{command_name}` is only available for subagents."})
    return False


def require_multi_agent(state: AgentsState, new_state: AgentsState, command_name: str, fallback_name: str | None = None) -> bool:
    n_agents = len(state["agent_order"])

    if n_agents > 1:
        return True

    suffix = f" Use `{fallback_name}` instead." if fallback_name else ""
    personal_output(state, new_state, {"tag": "ERROR", "content": f"`{command_name}` is not a valid command in single-agent mode.{suffix}"})
    return False


def require_single_agent(state: AgentsState, new_state: AgentsState, command_name: str) -> bool:
    n_agents = len(state["agent_order"])

    if n_agents == 1:
        return True

    personal_output(state, new_state, {"tag": "ERROR", "content": f"`{command_name}` is not a valid command in multi-agent mode."})
    return False


def require_no_active_proposal(state: AgentsState, new_state: AgentsState) -> bool:
    if state["proposal_state"]["state"] != "proposal":
        return True

    personal_output(state, new_state, {"tag": "ERROR", "content": "Cannot propose while voting is in session."})
    return False


class ExperimentCommand(BaseModel):
    title: str
    experiment: dict

    def payload(self) -> dict[str, object]:
        experiment = dict(self.experiment)
        for key in ("start_timestamp", "end_timestamp"):
            value = experiment.get(key)
            if isinstance(value, str):
                experiment[key] = iso_to_epoch_seconds(value)
        return {"title": self.title, "experiment": experiment}


class ProposeExperimentCommand(ExperimentCommand):
    command: Literal["propose_experiment"]

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_main_agent(state, new_state, self.command):
            return

        if not require_multi_agent(state, new_state, self.command, "submit_experiment"):
            return

        if not require_no_active_proposal(state, new_state):
            return

        agent_id = get_agent_id(state)
        proposal = self.payload()
        new_state["proposal_state"] = {
            "state": "proposal",
            "type": "experiment",
            "proposal": proposal,
            "agent_id": agent_id,
            "votes": [agent_id]
        }

        proposal_str = json.dumps(proposal, indent = 2)
        announce_proposal(state, new_state, agent_id, proposal_str, "an experiment")

class SubmitExperimentCommand(ExperimentCommand):
    command: Literal["submit_experiment"]

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_main_agent(state, new_state, self.command):
            return

        if not require_single_agent(state, new_state, self.command):
            return

        new_state["proposal_state"] = {
            "state": "submission",
            "type": "experiment",
            "submission": self.payload()
        }
    
class Layout(BaseModel):
    left: list[str]
    right: list[str]


class NotebookSelectQuery(SelectQuery):
    id: str

class NotebookCommand(BaseModel):
    title: str
    queries: list[NotebookSelectQuery]
    notes: dict[str, str]
    layout: Layout

    def payload(self) -> dict[str, object]:
        return {
            "title": self.title,
            "queries": [query.model_dump(by_alias = True) for query in self.queries],
            "notes": self.notes,
            "layout": self.layout.model_dump()
        }


class ProposeNotebookCommand(NotebookCommand):
    command: Literal["propose_notebook"]

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_main_agent(state, new_state, self.command):
            return

        if not require_multi_agent(state, new_state, self.command, "submit_notebook"):
            return

        if not require_no_active_proposal(state, new_state):
            return

        agent_id = get_agent_id(state)
        proposal = self.payload()
        proposal_str = json.dumps(proposal, indent = 2)
        announce_proposal(state, new_state, agent_id, proposal_str, "a notebook")
        new_state["proposal_state"] = {
            "state": "proposal",
            "type": "notebook",
            "proposal": proposal,
            "agent_id": agent_id,
            "votes": [agent_id]
        }


class SubmitNotebookCommand(NotebookCommand):
    command: Literal["submit_notebook"]

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_main_agent(state, new_state, self.command):
            return

        if not require_single_agent(state, new_state, self.command):
            return

        new_state["proposal_state"] = {
            "state": "submission",
            "type": "notebook",
            "submission": self.payload()
        }


class ProposeReportCommand(BaseModel):
    command: Literal["propose_report"]
    title: str
    report: str

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_subagent(state, new_state, self.command):
            return

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
                "title": self.title,
                "report": self.report
            },
            "agent_id": agent_id,
            "votes": [agent_id]
        }


class SubmitReportCommand(BaseModel):
    command: Literal["submit_report"]
    title: str
    report: str

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_subagent(state, new_state, self.command):
            return

        if not require_single_agent(state, new_state, self.command):
            return

        new_state["proposal_state"] = {
            "state": "submission",
            "type": "report",
            "submission": {
                "title": self.title,
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
            personal_output(state, new_state, {"tag": "ERROR", "content": "Voting is not in session."})
            return

        if agent_id in proposal_state["votes"]:
            personal_output(state, new_state, {"tag": "ERROR", "content": "You have already voted."})
            return

        global_output(state, new_state, {"tag": "VOTE", "content": f"{agent_id} has voted in favor of the proposal."}, ignore_current = False)
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

        global_output(state, new_state, {"tag": agent_id, "content": self.content})

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

    def run(self, state: AgentsState, new_state: AgentsState, subagent_pool: list["Agent"], open_router: OpenRouter, supabase: Client) -> None:
        from agents.agent_system import AgentSystem

        if state["is_subagent"]:
            personal_output(state, new_state, {"tag": "ERROR", "content": "`subagent` is not a valid command for subagents."})
            return

        pool_size = len(subagent_pool)

        if pool_size == 0:
            personal_output(state, new_state, {"tag": "ERROR", "content": "No subagent configurations available."})
            return

        selected_templates = self.select_templates(subagent_pool, self.n_agents)
        selected = self.clone_templates(selected_templates)

        sub_system = AgentSystem(agents = selected)
        sub_system.build_graph(open_router, supabase = supabase)
        
        sub_state = make_initial_state([agent.id for agent in selected], is_subagent = True)
        sub_state = update_state(sub_state, self.prompt)

        while sub_state["proposal_state"]["state"] != "submission":
            sub_state = sub_system.run(sub_state)

        proposal_state = sub_state["proposal_state"]

        if proposal_state["state"] != "submission":
            personal_output(state, new_state, {"tag": "ERROR", "content": "Subagent did not submit a report."})
            return

        if proposal_state["type"] != "report":
            personal_output(state, new_state, {"tag": "ERROR", "content": "Subagent submitted an invalid result type."})
            return

        report = proposal_state["submission"]["report"]

        personal_output(state, new_state, {"tag": "SUBAGENT REPORT", "content": report})


class AnalyzeDataCommand(BaseModel):
    command: Literal["analyze_data"]
    select: Annotated[
        list[Annotated[str, Field(min_length = 1)]],
        Field(min_length = 1)
    ]
    filters: list[Filter] = Field(default_factory = list)

    def run(self, state: AgentsState, new_state: AgentsState, supabase: Client) -> None:
        try:
            query = SelectQuery(select = self.select, filters = self.filters)
            query.run(supabase)
            personal_output(state, new_state, {"tag": "ANALYSIS", "content": format_select_results(query)})
        except Exception as error:
            personal_output(state, new_state, {"tag": "ERROR", "content": str(error)})

Command = Annotated[ProposeExperimentCommand | SubmitExperimentCommand | ProposeNotebookCommand | SubmitNotebookCommand | ProposeReportCommand | SubmitReportCommand | SubagentCommand | VoteCommand | MessageCommand | AnalyzeDataCommand, Field(discriminator = "command")]
