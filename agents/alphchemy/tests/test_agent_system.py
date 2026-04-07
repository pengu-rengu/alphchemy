from agents.agent_system import Agent, AgentSystem
from agents.data_paths import state_path
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


def test_initial_state_reuses_saved_state_without_validation() -> None:
    system = make_agent_system()
    saved_state = {"done": False}

    with patch.object(AgentSystem, "load_state", return_value = saved_state):
        state = system.initial_state("prompt")

    assert state is saved_state


def test_initial_state_reuses_saved_state() -> None:
    system = make_agent_system()
    saved_state = make_initial_state(["agent1"], "saved prompt")

    with patch.object(AgentSystem, "load_state", return_value = saved_state):
        state = system.initial_state("new prompt")

    assert state is saved_state


def test_initial_state_reuses_saved_state_when_subagent_flag_differs() -> None:
    system = make_agent_system()
    saved_state = make_initial_state(["agent1"], "saved prompt", True)

    with patch.object(AgentSystem, "load_state", return_value = saved_state):
        state = system.initial_state("new prompt", False)

    assert state is saved_state


def test_run_loops_until_submission() -> None:
    system = make_agent_system()
    graph = MagicMock()
    system.graph = graph
    system.summarize_node = MagicMock()

    initial_state = make_initial_state(["agent1"], "inspect")
    mid_state = make_initial_state(["agent1"], "inspect")
    final_state = make_initial_state(["agent1"], "inspect")
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
        "state": "submission",
        "type": "report",
        "submission": {"report": "done"}
    }
    assert graph.invoke.call_count == 2
    assert system.summarize_node.prompt == "inspect"


def test_run_persists_state_for_main_system() -> None:
    system = make_agent_system()
    graph = MagicMock()
    system.graph = graph
    system.summarize_node = MagicMock()

    initial_state = make_initial_state(["agent1"], "discover")
    final_state = make_initial_state(["agent1"], "discover")
    final_state["proposal_state"] = {
        "state": "submission",
        "type": "generator",
        "submission": {
            "generator": {},
            "param_space": {
                "search_space": {}
            }
        }
    }
    graph.invoke.return_value = final_state

    with patch.object(AgentSystem, "initial_state", return_value = initial_state):
        with patch("builtins.open", mock_open()) as mocked_file:
            with patch("agents.agent_system.json.dump") as mock_dump:
                result = system.run("discover")

    assert result["type"] == "generator"
    assert result["submission"] == {
        "generator": {},
        "param_space": {
            "search_space": {}
        }
    }
    mocked_file.assert_called_with(state_path(), "w")
    mock_dump.assert_called_once()


def test_run_does_not_persist_state_for_subagents() -> None:
    system = make_agent_system()
    graph = MagicMock()
    system.graph = graph
    system.summarize_node = MagicMock()

    initial_state = make_initial_state(["agent1"], "inspect", True)
    final_state = make_initial_state(["agent1"], "inspect", True)
    final_state["proposal_state"] = {
        "state": "submission",
        "type": "report",
        "submission": {
            "report": "done"
        }
    }
    graph.invoke.return_value = final_state

    with patch.object(AgentSystem, "initial_state", return_value = initial_state):
        with patch("builtins.open", mock_open()) as mocked_file:
            result = system.run("inspect", is_subagent = True)

    assert result["submission"] == {"report": "done"}
    mocked_file.assert_not_called()
