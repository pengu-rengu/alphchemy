import importlib
from typing import Any

from agents.commands import SubagentCommand


class StubSubAgentSystem:
    graph_supabase: Any = None
    run_supabase: Any = None

    def __init__(self, agents: list[Any]) -> None:
        self.agents = agents

    def build_graph(self, open_router: Any, supabase: Any) -> None:
        StubSubAgentSystem.graph_supabase = supabase

    def run(
        self,
        start_state: dict[str, Any] | None,
        user_prompt: str,
        supabase: Any,
        is_subagent: bool = False
    ) -> dict[str, Any]:
        StubSubAgentSystem.run_supabase = supabase

        return {
            "proposal_state": {
                "state": "submission",
                "type": "report",
                "submission": {
                    "report": "subagent findings"
                }
            }
        }


def test_subagent_command_reads_report_from_proposal_state(monkeypatch: Any) -> None:
    agent_system_module = importlib.import_module("agents.agent_system")
    monkeypatch.setattr(agent_system_module, "AgentSystem", StubSubAgentSystem)

    command = SubagentCommand(
        command = "subagent",
        prompt = "review generated experiments",
        n_agents = 1
    )
    state = {
        "is_subagent": False,
        "agent_order": ["Main"],
        "turn": 0,
        "proposal_state": {
            "state": "idle"
        }
    }
    new_state = {
        "agent_contexts": {
            "updates": {
                "Main": {
                    "personal_output": "",
                    "global_output": ""
                }
            }
        }
    }
    agent_class = agent_system_module.Agent
    subagent_pool = [
        agent_class(
            id = "Worker",
            max_context_len = 10,
            n_delete = 2,
            chat_models = ["chat-model"],
            summarize_models = ["summary-model"]
        )
    ]
    supabase = object()

    command.run(state, new_state, subagent_pool, object(), supabase)

    output = new_state["agent_contexts"]["updates"]["Main"]["personal_output"]
    assert "[SUBAGENT REPORT]\nsubagent findings\n\n" == output
    assert StubSubAgentSystem.graph_supabase is supabase
    assert StubSubAgentSystem.run_supabase is supabase
