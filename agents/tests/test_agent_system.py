from agents.agent_system import Agent, AgentSystem
from agents.state import make_initial_state
from unittest.mock import MagicMock, mock_open, patch


def make_agent_system() -> AgentSystem:
    agent = Agent(
        id = "agent1",
        max_context_len = 1,
        n_delete = 1,
        chat_models = ["model1"],
        summarize_models = ["model1"]
    )
    return AgentSystem(agents = [agent])


def test_initial_state_ignores_invalid_saved_state() -> None:
    system = make_agent_system()

    with patch.object(AgentSystem, "load_state", return_value = {"done": False}):
        state = system.initial_state(None)

    assert state["proposal_state"] == {
        "state": "idle"
    }


def test_run_loops_until_submission() -> None:
    system = make_agent_system()
    graph = MagicMock()
    system.graph = graph

    initial_state = make_initial_state(["agent1"])
    mid_state = make_initial_state(["agent1"])
    final_state = make_initial_state(["agent1"])
    final_state["proposal_state"] = {
        "state": "submission",
        "type": "report",
        "submission": {
            "report": "done"
        }
    }
    graph.invoke.side_effect = [mid_state, final_state]

    with patch.object(AgentSystem, "initial_state", return_value = initial_state):
        result = system.run("inspect")

    assert result == {
        "report": "done"
    }
    assert graph.invoke.call_count == 2


def test_run_persists_state_for_main_system() -> None:
    system = make_agent_system()
    graph = MagicMock()
    system.graph = graph

    initial_state = make_initial_state(["agent1"])
    final_state = make_initial_state(["agent1"])
    final_state["proposal_state"] = {
        "state": "submission",
        "type": "generator",
        "submission": {
            "generator": {},
            "search_space": {}
        }
    }
    graph.invoke.return_value = final_state

    with patch.object(AgentSystem, "initial_state", return_value = initial_state):
        with patch("builtins.open", mock_open()) as mocked_file:
            with patch("agents.agent_system.json.dump") as mock_dump:
                result = system.run()

    assert result == {
        "generator": {},
        "search_space": {}
    }
    mocked_file.assert_called_with("../data/state.json", "w")
    mock_dump.assert_called_once()
