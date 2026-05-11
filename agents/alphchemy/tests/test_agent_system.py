import importlib
import sys
import types
from typing import Any

class StubStartTurnNode:

    def __call__(self, state: dict[str, Any]) -> dict[str, Any]:
        return {}


class StubLLMNode:

    def __init__(self, open_router: Any, models: dict[str, list[str]]) -> None:
        self.open_router = open_router
        self.models = models

    def __call__(self, state: dict[str, Any]) -> dict[str, Any]:
        return {
            "proposal_state": {
                "state": "submission",
                "type": "report",
                "submission": {
                    "report": "stub report"
                }
            },
            "commands": [],
            "params": []
        }


class StubSummarizeNode:

    def __init__(
        self,
        open_router: Any,
        n_delete: dict[str, int],
        models: dict[str, list[str]]
    ) -> None:
        self.open_router = open_router
        self.n_delete = n_delete
        self.models = models

    def __call__(self, state: dict[str, Any]) -> dict[str, Any]:
        return {}


class StubCommandNode:

    def __init__(
        self,
        open_router: Any,
        subagent_pool: list[Any],
        supabase: Any
    ) -> None:
        self.open_router = open_router
        self.subagent_pool = subagent_pool
        self.supabase = supabase

    def __call__(self, state: dict[str, Any]) -> dict[str, Any]:
        return {}


class StubEndTurnNode:

    def __call__(self, state: dict[str, Any]) -> dict[str, Any]:
        return {}


def load_agent_system_module(monkeypatch: Any) -> Any:
    stub_nodes = types.ModuleType("agents.nodes")
    stub_nodes.StartTurnNode = StubStartTurnNode
    stub_nodes.LLMNode = StubLLMNode
    stub_nodes.SummarizeNode = StubSummarizeNode
    stub_nodes.CommandNode = StubCommandNode
    stub_nodes.EndTurnNode = StubEndTurnNode

    monkeypatch.setitem(sys.modules, "agents.nodes", stub_nodes)
    sys.modules.pop("agents.agent_system", None)

    return importlib.import_module("agents.agent_system")


def build_agent_system(agent_system_module: Any) -> Any:
    return agent_system_module.AgentSystem(
        agents = [
            agent_system_module.Agent(
                id = "Tester",
                max_context_len = 10,
                n_delete = 2,
                chat_models = ["chat-model"],
                summarize_models = ["summary-model"]
            )
        ]
    )


def test_run_returns_submission_state(monkeypatch: Any) -> None:
    agent_system_module = load_agent_system_module(monkeypatch)

    agent_system = build_agent_system(agent_system_module)
    agent_system.build_graph(open_router = object(), supabase = object())

    result = agent_system.run(None, "test prompt", supabase = object())

    assert result["proposal_state"]["state"] == "submission"
    assert result["proposal_state"]["submission"]["report"] == "stub report"


def test_run_subagent_returns_submission_state(monkeypatch: Any) -> None:
    agent_system_module = load_agent_system_module(monkeypatch)

    agent_system = build_agent_system(agent_system_module)
    agent_system.build_graph(open_router = object(), supabase = object())

    result = agent_system.run(None, "test prompt", supabase = object(), is_subagent = True)

    assert result["proposal_state"]["state"] == "submission"
    assert result["proposal_state"]["submission"]["report"] == "stub report"
