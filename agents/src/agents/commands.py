from agents.state import AgentsState, personal_output, global_output, get_agent_id
from agents.data_paths import experiments_path
from pydantic import BaseModel, Field, model_validator, StrictInt, StrictFloat
from typing import Annotated, Literal, TYPE_CHECKING
from dataframe_parse import parse_experiment, parse_results
from openrouter import OpenRouter
from collections import defaultdict
import pandas as pd
import random
import json

if TYPE_CHECKING:
    from agents.agent_system import Agent

def announce_proposal(state: AgentsState, new_state: AgentsState, agent_id: str, proposal: str, subject: str) -> None:
    global_output(state, new_state, f"[PROPOSAL] {agent_id} has proposed {subject}. Voting is now in session.\n", ignore_current = False)
    global_output(state, new_state, f"{proposal}\n\n", ignore_current = False)


def require_workflow_mode(state: AgentsState, new_state: AgentsState, command_name: str, workflow_mode: str) -> bool:
    current_mode = state["workflow_mode"]

    if current_mode == workflow_mode:
        return True

    personal_output(state, new_state, f"[ERROR] `{command_name}` is not a valid command in {current_mode} mode.\n\n")
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

class ParamSpacePayload(BaseModel):
    search_space: dict[str, list]


class ExperimentsCommand(BaseModel):
    generator: dict
    param_space: ParamSpacePayload

    @model_validator(mode = "before")
    @classmethod
    def normalize_param_space(cls, data: object) -> object:
        if not isinstance(data, dict):
            return data

        if "param_space" in data:
            return data

        maybe_search_space = data.get("search_space")
        if not isinstance(maybe_search_space, dict):
            return data

        normalized = data.copy()
        normalized["param_space"] = {
            "search_space": maybe_search_space
        }
        return normalized

    def payload(self) -> dict[str, object]:
        return {
            "generator": self.generator,
            "param_space": self.param_space.model_dump()
        }


class ProposeExperimentsCommand(ExperimentsCommand):
    command: Literal["propose_experiments"]

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_workflow_mode(state, new_state, self.command, "generator"):
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
        if not require_workflow_mode(state, new_state, self.command, "generator"):
            return

        if not require_single_agent(state, new_state, self.command):
            return

        submission = self.payload()
        new_state["proposal_state"] = {
            "state": "submission",
            "type": "generator",
            "submission": submission
        }
    
class ProposeReportCommand(BaseModel):
    command: Literal["propose_report"]
    report: str

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_workflow_mode(state, new_state, self.command, "report"):
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
                "report": self.report
            },
            "agent_id": agent_id,
            "votes": [agent_id]
        }

class SubmitReportCommand(BaseModel):
    command: Literal["submit_report"]
    report: str

    def run(self, state: AgentsState, new_state: AgentsState):
        if not require_workflow_mode(state, new_state, self.command, "report"):
            return

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
        submission = sub_system.run("report", self.prompt, is_subagent = True)
        report = submission["report"]

        personal_output(state, new_state, f"[SUBAGENT REPORT]\n{report}\n\n")


class AnalyzeDataFilter(BaseModel):
    column: Annotated[str, Field(min_length = 1)]
    equals: StrictInt | StrictFloat | None = None
    min_value: StrictInt | StrictFloat | None = None
    max_value: StrictInt | StrictFloat | None = None

    @model_validator(mode = "after")
    def validate_filter(self) -> "AnalyzeDataFilter":
        has_equals = self.equals is not None
        has_min = self.min_value is not None
        has_max = self.max_value is not None

        if not has_equals and not has_min and not has_max:
            raise ValueError("Filter must include `equals`, `min_value`, or `max_value`")

        if has_equals and (has_min or has_max):
            raise ValueError("`equals` cannot be combined with `min_value` or `max_value`")

        if has_min and has_max and self.min_value > self.max_value:
            raise ValueError("`min_value` cannot be greater than `max_value`")

        return self

class AnalyzeDataCommand(BaseModel):
    command: Literal["analyze_data"]
    column: Annotated[str, Field(min_length = 1)]
    filters: list[AnalyzeDataFilter] = Field(default_factory = list)

    def build_dataframe(self) -> pd.DataFrame:
        rows = []
        path = experiments_path()

        with open(path, "r") as file:
            for line_index, line in enumerate(file):
                if not line.strip():
                    continue

                try:
                    data = json.loads(line)
                    row = {}

                    parse_experiment(row, data["experiment"])
                    parse_results(row, data["results"])

                    row["id"] = float(line_index)
                    rows.append(row)
                except Exception:
                    continue

        return pd.DataFrame(rows, dtype = float)

    def require_column(self, df: pd.DataFrame, column: str) -> pd.Series:
        if column not in df.columns:
            raise ValueError(f"Column `{column}` not found")

        return df[column]

    def validate_float_series(self, series: pd.Series, column: str) -> None:
        if pd.api.types.is_float_dtype(series):
            return

        raise ValueError(f"Column `{column}` must contain float values")

    def apply_filter(self, df: pd.DataFrame, data_filter: AnalyzeDataFilter) -> pd.DataFrame:
        series = self.require_column(df, data_filter.column)
        self.validate_float_series(series, data_filter.column)

        if data_filter.equals is not None:
            return df[series == data_filter.equals]

        filtered_df = df

        if data_filter.min_value is not None:
            filtered_df = filtered_df[filtered_df[data_filter.column] >= data_filter.min_value]

        if data_filter.max_value is not None:
            filtered_df = filtered_df[filtered_df[data_filter.column] <= data_filter.max_value]

        return filtered_df

    def format_summary(self, filtered_df: pd.DataFrame, target: pd.Series) -> str:
        lines = [
            "[ANALYSIS]",
            f"column: {self.column}",
            f"rows_matched: {len(filtered_df)}",
            f"values_used: {len(target)}",
            f"min: {float(target.min())}",
            f"q1: {float(target.quantile(0.25))}",
            f"median: {float(target.median())}",
            f"q3: {float(target.quantile(0.75))}",
            f"max: {float(target.max())}",
            f"mean: {float(target.mean())}",
            f"std: {float(target.std(ddof = 0))}"
        ]

        return "\n".join(lines) + "\n\n"

    def run(self, state: AgentsState, new_state: AgentsState) -> None:
        try:
            df = self.build_dataframe()
        except FileNotFoundError:
            personal_output(state, new_state, "[ERROR] Could not find `../data/experiments.jsonl`.\n\n")
            return
        except Exception as error:
            personal_output(state, new_state, f"[ERROR] Failed to build analysis dataframe: {error}\n\n")
            return

        try:
            filtered_df = df

            for data_filter in self.filters:
                filtered_df = self.apply_filter(filtered_df, data_filter)

            target_series = self.require_column(filtered_df, self.column)
            self.validate_float_series(target_series, self.column)
        except ValueError as error:
            personal_output(state, new_state, f"[ERROR] {error}\n\n")
            return

        target = target_series.dropna()

        if filtered_df.empty:
            personal_output(state, new_state, "[ERROR] No rows matched the requested filters.\n\n")
            return

        if target.empty:
            personal_output(state, new_state, f"[ERROR] Column `{self.column}` has no values after filtering.\n\n")
            return

        summary = self.format_summary(filtered_df, target)
        personal_output(state, new_state, summary)

Command = Annotated[ProposeExperimentsCommand | SubmitExperimentsCommand | ProposeReportCommand | SubmitReportCommand | SubagentCommand | VoteCommand | MessageCommand | AnalyzeDataCommand, Field(discriminator = "command")]
