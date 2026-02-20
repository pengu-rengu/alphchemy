
from typing import Literal, Annotated
from langgraph.graph import StateGraph, START, END
from langgraph.types import Overwrite, RetryPolicy
from ontology.updater import OntologyUpdater
from agents.nodes import StartTurnNode, LLMNode, PlanNode, SummarizeNode, CommandNode, EndTurnNode
from agents.state import AgentsState, get_agent_id, make_initial_state
from openrouter import OpenRouter
from pydantic import BaseModel, Field, ConfigDict, model_validator
import os
import json
import redis

class Agent(BaseModel):
    id: Annotated[str, Field(min_length = 1)]
    plan_freq: Annotated[int, Field(ge = 1)]
    max_context_len: Annotated[int, Field(ge = 1)]
    n_delete: Annotated[int, Field(ge = 1)]
    chat_models: Annotated[list[str], Field(min_length = 1)]
    plan_models: Annotated[list[str], Field(min_length = 1)]
    summarize_models: Annotated[list[str], Field(min_length = 1)]

class AgentSystem(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed = True)
    
    agents: list[Agent]

    graph: Annotated[StateGraph | None, Field(default = None, exclude = True)]

    @model_validator(mode = "after")
    def validate_agent_ids(self):

        agent_ids = [agent.id for agent in self.agents]
        unique_agent_ids = set(agent_ids)

        agent_ids_len = len(agent_ids)
        unique_agent_ids_len = len(unique_agent_ids)

        if agent_ids_len != unique_agent_ids_len:
            raise ValueError("Agent IDs must be unique")
        
        return self
    
    def build_graph(self, updater: OntologyUpdater, open_router: OpenRouter, redis_client: redis.Redis):
        
        start_turn_node = StartTurnNode(
            redis_client = redis_client,
            updater = updater
        )
        llm_node = LLMNode(
            open_router = open_router,
            models = {agent.id: agent.chat_models for agent in self.agents}
        )
        plan_node = PlanNode(
            open_router = open_router,
            models = {agent.id: agent.plan_models for agent in self.agents},
            plan_freq = {agent.id: agent.plan_freq for agent in self.agents}
        )
        summarize_node = SummarizeNode(
            open_router = open_router,
            n_delete = {agent.id: agent.n_delete for agent in self.agents},
            models = {agent.id: agent.summarize_models for agent in self.agents}
        )
        command_node = CommandNode(
            updater = updater
        )
        end_turn_node = EndTurnNode(
            redis_client = redis_client
        )

        retry_policy = RetryPolicy()

        graph = StateGraph(AgentsState)
        graph.add_node("start_turn", start_turn_node)
        graph.add_node("plan", plan_node, retry_policy = retry_policy)
        graph.add_node("summarize", summarize_node, retry_policy = retry_policy)
        graph.add_node("llm", llm_node, retry_policy = retry_policy)
        graph.add_node("command", command_node)
        graph.add_node("end_turn", end_turn_node)

        graph.add_edge(START, "start_turn")
        graph.add_edge("start_turn", "llm")
        graph.add_edge("llm", "plan")
        graph.add_conditional_edges("plan", self.summarize_router)
        graph.add_conditional_edges("command", self.command_router)
        graph.add_edge("end_turn", END)

        self.graph = graph.compile()

    def summarize_router(self, state: AgentsState) -> Literal["summarize", "command"]:
        agent_id = get_agent_id(state)
        n_messages = len(state["agent_contexts"][agent_id])

        max_context_len = next(agent.max_context_len for agent in self.agents if agent.id == agent_id)

        if n_messages > max_context_len:
            return "summarize"
        
        return "command"

    def command_router(self, state: AgentsState) -> Literal["command", "end_turn"]:
        if not state["commands"]:
            return "end_turn"
        
        return "command"
    
    def initial_state(self):

        if os.path.exists("data/state.json"):

            with open("data/state.json", "r") as file:
                return json.load(file)
            
        else:

            return make_initial_state([agent.id for agent in self.agents])

    def run(self):

        state = self.initial_state()

        while True:
            state["system_prompts"] = Overwrite(state["system_prompts"])
            state["plans"] = Overwrite(state["plans"])
            state["summaries"] = Overwrite(state["summaries"])
            state["agent_contexts"] = Overwrite(state["agent_contexts"])
            state["votes"] = Overwrite(state["votes"])
            state["plan_counters"] = Overwrite(state["plan_counters"])

            state = self.graph.invoke(state)
            with open("data/state.json", "w") as file:
                json.dump(state, file, indent = 4)
    