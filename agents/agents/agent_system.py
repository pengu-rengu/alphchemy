
from typing import Literal
from dataclasses import dataclass
from langgraph.graph import StateGraph, START, END
from langgraph.types import Overwrite, RetryPolicy
from ontology.ontology import Ontology
from agents.nodes import StartTurnNode, LLMNode, SummarizeNode, CommandNode, EndTurnNode
from agents.state import AgentsState, get_agent_id
from openrouter import OpenRouter
import json
import redis

@dataclass
class AgentSystem:
    max_context_len: int
    delete_frac: float
    models: list[str]

    def build_graph(self, ontology: Ontology, open_router: OpenRouter, redis_client: redis.Redis):
        
        start_turn_node = StartTurnNode(redis_client=redis_client)
        llm_node = LLMNode(
            open_router = open_router,
            models = self.models
        )
        summarize_node = SummarizeNode(
            open_router = open_router,
            delete_frac = self.delete_frac,
            models = self.models
        )
        command_node = CommandNode(
            ontology = ontology
        )
        end_turn_node = EndTurnNode(redis_client=redis_client)

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
    
    def run(self, initial_state: AgentsState):

        state = initial_state

        while True:
            state["system_prompts"] = Overwrite(state["system_prompts"])
            state["summaries"] = Overwrite(state["summaries"])
            state["agent_contexts"] = Overwrite(state["agent_contexts"])
            state["votes"] = Overwrite(state["votes"])

            state = self.graph.invoke(state)
            with open("data/state.json", "w") as file:
                json.dump(state, file, indent = 4)
    