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


def test_initial_state_reuses_saved_state_without_validation() -> None:
    system = make_agent_system()
    saved_state = {"done": False}

    with patch.object(AgentSystem, "load_state", return_value = saved_state):
        state = system.initial_state("generator", "prompt")

    assert state is saved_state


def test_initial_state_reuses_saved_state_when_mode_matches() -> None:
    system = make_agent_system()
    saved_state = make_initial_state(["agent1"], "generator", "saved prompt")

    with patch.object(AgentSystem, "load_state", return_value = saved_state):
        state = system.initial_state("generator", "new prompt")

    assert state is saved_state


def test_initial_state_reuses_saved_state_when_mode_differs() -> None:
    system = make_agent_system()
    saved_state = make_initial_state(["agent1"], "generator", "saved prompt")

    with patch.object(AgentSystem, "load_state", return_value = saved_state):
        state = system.initial_state("report", "new prompt")

    assert state is saved_state


def test_initial_state_reuses_saved_state_when_subagent_flag_differs() -> None:
    system = make_agent_system()
    saved_state = make_initial_state(["agent1"], "report", "saved prompt", True)

    with patch.object(AgentSystem, "load_state", return_value = saved_state):
        state = system.initial_state("report", "new prompt", False)

    assert state is saved_state


def test_run_loops_until_submission() -> None:
    system = make_agent_system()
    graph = MagicMock()
    system.graph = graph
    system.summarize_node = MagicMock()

    initial_state = make_initial_state(["agent1"], "report", "inspect")
    mid_state = make_initial_state(["agent1"], "report", "inspect")
    final_state = make_initial_state(["agent1"], "report", "inspect")
    final_state["proposal_state"] = {
        "state": "submission",
        "type": "report",
        "submission": {
            "report": "done"
        }
    }
    graph.invoke.side_effect = [mid_state, final_state]

    with patch.object(AgentSystem, "initial_state", return_value = initial_state):
        result = system.run("report", "inspect")

    assert result == {
        "report": "done"
    }
    assert graph.invoke.call_count == 2
    assert system.summarize_node.prompt == "inspect"


def test_run_persists_state_for_main_system() -> None:
    system = make_agent_system()
    graph = MagicMock()
    system.graph = graph
    system.summarize_node = MagicMock()

    initial_state = make_initial_state(["agent1"], "generator", "discover")
    final_state = make_initial_state(["agent1"], "generator", "discover")
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
                result = system.run("generator", "discover")

    assert result == {
        "generator": {},
        "search_space": {}
    }
    mocked_file.assert_called_with("../data/state.json", "w")
    mock_dump.assert_called_once()


def test_run_does_not_persist_state_for_subagents() -> None:
    system = make_agent_system()
    graph = MagicMock()
    system.graph = graph
    system.summarize_node = MagicMock()

    initial_state = make_initial_state(["agent1"], "report", "inspect", True)
    final_state = make_initial_state(["agent1"], "report", "inspect", True)
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
            result = system.run("report", "inspect", is_subagent = True)

    assert result == {
        "report": "done"
    }
    mocked_file.assert_not_called()
