
from typing import Literal
from dataclasses import dataclass
from langgraph.graph import StateGraph, START, END
from langgraph.types import Overwrite, RetryPolicy
from ontology.ontology import Ontology
from ontology.updater import OntologyUpdater
from agents.nodes import StartTurnNode, LLMNode, SummarizeNode, CommandNode, EndTurnNode
from agents.state import AgentsState, get_agent_id, make_initial_state
from openrouter import OpenRouter
import os
import json
import redis

@dataclass
class Agent:
    id: str
    chat_models: list[str]
    summarize_models: list[str]

@dataclass
class AgentSystem:
    max_context_len: int
    delete_frac: float
    agents: list[Agent]

    def build_graph(self, updater: OntologyUpdater, open_router: OpenRouter, redis_client: redis.Redis):
        
        start_turn_node = StartTurnNode(
            redis_client = redis_client,
            updater = updater
        )
        llm_node = LLMNode(
            open_router = open_router,
            models = {agent.id: agent.chat_models for agent in self.agents}
        )
        summarize_node = SummarizeNode(
            open_router = open_router,
            delete_frac = self.delete_frac,
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
        graph.add_node("summarize", summarize_node, retry_policy = retry_policy)
        graph.add_node("llm", llm_node, retry_policy = retry_policy)
        graph.add_node("command", command_node)
        graph.add_node("end_turn", end_turn_node)

        graph.add_edge(START, "start_turn")
        graph.add_edge("start_turn", "llm")
        graph.add_conditional_edges("llm", self.summarize_router)
        graph.add_conditional_edges("command", self.command_router)
        graph.add_edge("end_turn", END)

        self.graph = graph.compile()

    def summarize_router(self, state: AgentsState) -> Literal["summarize", "command"]:
        agent_id = get_agent_id(state)
        n_messages = len(state["agent_contexts"][agent_id])

        if n_messages > self.max_context_len:
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
            state["summaries"] = Overwrite(state["summaries"])
            state["agent_contexts"] = Overwrite(state["agent_contexts"])
            state["votes"] = Overwrite(state["votes"])

            state = self.graph.invoke(state)
            with open("data/state.json", "w") as file:
                json.dump(state, file, indent = 4)
    