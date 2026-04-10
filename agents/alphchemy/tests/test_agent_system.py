import importlib
import json
import sys
import types
from pathlib import Path
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
        models: dict[str, list[str]],
        prompt: str
    ) -> None:
        self.open_router = open_router
        self.n_delete = n_delete
        self.models = models
        self.prompt = prompt

    def __call__(self, state: dict[str, Any]) -> dict[str, Any]:
        return {}


class StubCommandNode:

    def __init__(self, open_router: Any, subagent_pool: list[Any]) -> None:
        self.open_router = open_router
        self.subagent_pool = subagent_pool

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


def test_run_subagent_keeps_state_in_memory(monkeypatch: Any, tmp_path: Path) -> None:
    state_file = tmp_path / "state.json"

    agent_system_module = load_agent_system_module(monkeypatch)
    monkeypatch.setattr(agent_system_module, "state_path", lambda: state_file)

    agent_system = build_agent_system(agent_system_module)
    agent_system.build_graph(open_router = object())

    result = agent_system.run("test prompt", is_subagent = True)

    assert result["state"] == "submission"
    assert result["submission"]["report"] == "stub report"
    assert not state_file.exists()


def test_run_persists_main_state(monkeypatch: Any, tmp_path: Path) -> None:
    state_file = tmp_path / "state.json"

    agent_system_module = load_agent_system_module(monkeypatch)
    monkeypatch.setattr(agent_system_module, "state_path", lambda: state_file)

    agent_system = build_agent_system(agent_system_module)
    agent_system.build_graph(open_router = object())

    result = agent_system.run("test prompt")

    with open(state_file, "r") as file:
        saved_state = json.load(file)

    assert result["state"] == "submission"
    assert saved_state["proposal_state"]["state"] == "submission"
    assert saved_state["proposal_state"]["submission"]["report"] == "stub report"
