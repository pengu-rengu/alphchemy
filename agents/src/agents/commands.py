from agents.state import AgentsState, personal_output, global_output, get_agent_id
from pydantic import BaseModel, Field, model_validator, StrictInt, StrictFloat
from typing import Annotated, Literal, TYPE_CHECKING
from dataframe_parse import parse_experiment, parse_results
from generator.generators import ExperimentGen
from generator.params import ParamSpace
from openrouter import OpenRouter
from collections import defaultdict
import pandas as pd
import random
import json
import redis

if TYPE_CHECKING:
    from agents.agent_system import Agent


def execute_generator(generator_json: dict, search_space: dict[str, list], redis_client: redis.Redis) -> int:
    return

    experiment_gen = ExperimentGen.model_validate(generator_json)
    param_space = ParamSpace(search_space = search_space)
    experiments = param_space.generate_experiments(experiment_gen, 1000)
    
    for experiment in experiments:
        serialized = json.dumps(experiment)
        redis_client.lpush("experiments", serialized)

    return len(experiments)

def announce_proposal(state: AgentsState, new_state: AgentsState, agent_id: str, proposal: str, subject: str) -> None:
    global_output(
        state,
        new_state,
        f"[PROPOSAL] {agent_id} has proposed {subject}. Voting is now in session.\n",
        ignore_current = False
    )
    global_output(state, new_state, f"{proposal}\n\n", ignore_current = False)

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
        announce_proposal(state, new_state, agent_id, proposal_data, "an experiment generator")

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

        try:
            execute_generator(self.generator, self.search_space, redis_client)
        except Exception as error:
            personal_output(state, new_state, f"[ERROR] Error occurred when executing: {error}\n\n")
            return

        personal_output(state, new_state, "[SUBMISSION] Experiment generation submitted.\n\n")
        new_state["experiments_running"] = True
        new_state["done"] = True

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
        announce_proposal(state, new_state, agent_id, self.content, "a report")

class SubmitReportCommand(BaseModel):
    command: Literal["submit_report"]
    content: str

    def run(self, state: AgentsState, new_state: AgentsState):
        n_agents = len(state["agent_order"])

        if n_agents > 1:
            personal_output(state, new_state, "[ERROR] `submit_report` is not a valid command in multi-agent mode.\n\n")
            return

        new_state["report"] = self.content
        new_state["done"] = True

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

        with open("../data/experiments.jsonl", "r") as file:
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

class SubagentCommand(BaseModel):
    command: Literal["subagent"]
    task: str
    n_agents: Annotated[int, Field(ge = 1, le = 2)]

    def select_templates(self, subagent_pool: list["Agent"], n_agents: int) -> list["Agent"]:
        
        if n_agents <= len(subagent_pool):
            return random.sample(subagent_pool, n_agents)

        selected_templates = []

        for _ in range(n_agents):
            selected_templates.append(random.choice(subagent_pool))

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

    def run(self, state: AgentsState, new_state: AgentsState, subagent_pool: list["Agent"], open_router: OpenRouter, redis_client: redis.Redis) -> None:
        from agents.agent_system import AgentSystem

        pool_size = len(subagent_pool)

        if pool_size == 0:
            personal_output(state, new_state, "[ERROR] No subagent configurations available.\n\n")
            return

        selected_templates = self.select_templates(subagent_pool, self.n_agents)
        selected = self.clone_templates(selected_templates)

        sub_system = AgentSystem(agents = selected)
        sub_system.build_graph(open_router, redis_client)
        report = sub_system.run_task(self.task)

        personal_output(state, new_state, f"[SUBAGENT REPORT]\n{report}\n\n")

Command = Annotated[ProposeExperimentsCommand | SubmitExperimentsCommand | ProposeReportCommand | SubmitReportCommand | AnalyzeDataCommand | SubagentCommand | VoteCommand | MessageCommand, Field(discriminator = "command")]
