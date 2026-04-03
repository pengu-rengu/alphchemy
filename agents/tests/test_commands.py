from agents.agent_system import Agent, AgentSystem
from agents.commands import ProposeExperimentsCommand, SubmitExperimentsCommand, SubmitReportCommand, SubagentCommand, VoteCommand
from agents.state import make_initial_state
from unittest.mock import MagicMock, patch


def make_output_state(agent_order: list[str]) -> dict[str, dict[str, dict[str, dict[str, str]]]]:
    return {
        "agent_contexts": {
            "updates": {
                agent_id: {
                    "personal_output": "",
                    "global_output": ""
                } for agent_id in agent_order
            }
        }
    }


def make_state(agent_order: list[str], workflow_mode: str, is_subagent: bool = False):
    return make_initial_state(agent_order, workflow_mode, "prompt", is_subagent)


def test_propose_experiments_command_sets_proposal_state() -> None:
    state = make_state(["agent1", "agent2"], "generator")
    new_state = make_output_state(state["agent_order"])
    command = ProposeExperimentsCommand(
        command = "propose_experiments",
        generator = {"title": "test"},
        search_space = {"x": [1]}
    )

    command.run(state, new_state)

    assert new_state["proposal_state"] == {
        "state": "proposal",
        "type": "generator",
        "proposal": {
            "generator": {"title": "test"},
            "search_space": {"x": [1]}
        },
        "agent_id": "agent1",
        "votes": ["agent1"]
    }


def test_submit_experiments_command_sets_submission_state() -> None:
    state = make_state(["agent1"], "generator")
    new_state = make_output_state(state["agent_order"])
    command = SubmitExperimentsCommand(
        command = "submit_experiments",
        generator = {"title": "test"},
        search_space = {"x": [1]}
    )

    command.run(state, new_state)

    assert new_state["proposal_state"] == {
        "state": "submission",
        "type": "generator",
        "submission": {
            "generator": {"title": "test"},
            "search_space": {"x": [1]}
        }
    }


def test_submit_report_command_sets_dict_submission() -> None:
    state = make_state(["agent1"], "report")
    new_state = make_output_state(state["agent_order"])
    command = SubmitReportCommand(
        command = "submit_report",
        report = "report body"
    )

    command.run(state, new_state)

    assert new_state["proposal_state"] == {
        "state": "submission",
        "type": "report",
        "submission": {
            "report": "report body"
        }
    }


def test_vote_command_preserves_proposal_type() -> None:
    state = make_state(["agent1", "agent2"], "report")
    state["turn"] = 1
    state["proposal_state"] = {
        "state": "proposal",
        "type": "report",
        "proposal": {
            "report": "draft"
        },
        "agent_id": "agent1",
        "votes": ["agent1"]
    }
    new_state = make_output_state(state["agent_order"])
    command = VoteCommand(command = "vote")

    command.run(state, new_state)

    assert new_state["proposal_state"] == {
        "state": "proposal",
        "type": "report",
        "proposal": {
            "report": "draft"
        },
        "agent_id": "agent1",
        "votes": ["agent1", "agent2"]
    }


def test_submit_experiments_command_rejects_report_mode() -> None:
    state = make_state(["agent1"], "report")
    new_state = make_output_state(state["agent_order"])
    command = SubmitExperimentsCommand(
        command = "submit_experiments",
        generator = {"title": "test"},
        search_space = {"x": [1]}
    )

    command.run(state, new_state)

    assert new_state["agent_contexts"]["updates"]["agent1"]["personal_output"] == "[ERROR] `submit_experiments` is not a valid command in report mode.\n\n"
    assert "proposal_state" not in new_state


def test_submit_report_command_rejects_generator_mode() -> None:
    state = make_state(["agent1"], "generator")
    new_state = make_output_state(state["agent_order"])
    command = SubmitReportCommand(
        command = "submit_report",
        report = "report body"
    )

    command.run(state, new_state)

    assert new_state["agent_contexts"]["updates"]["agent1"]["personal_output"] == "[ERROR] `submit_report` is not a valid command in generator mode.\n\n"
    assert "proposal_state" not in new_state


@patch.object(AgentSystem, "build_graph")
@patch.object(AgentSystem, "run", return_value = {"report": "done"})
def test_subagent_command_runs_report_mode(mock_run, mock_build_graph) -> None:
    state = make_state(["agent1"], "report")
    new_state = make_output_state(state["agent_order"])
    template = Agent(
        id = "sub",
        max_context_len = 5,
        n_delete = 2,
        chat_models = ["model"],
        summarize_models = ["model"]
    )
    command = SubagentCommand(command = "subagent", prompt = "inspect this", n_agents = 1)

    command.run(state, new_state, [template], MagicMock())

    mock_build_graph.assert_called_once()
    mock_run.assert_called_once_with("report", "inspect this", is_subagent = True)
    assert new_state["agent_contexts"]["updates"]["agent1"]["personal_output"] == "[SUBAGENT REPORT]\ndone\n\n"


@patch.object(AgentSystem, "build_graph")
@patch.object(AgentSystem, "run")
def test_subagent_command_rejects_nested_subagents(mock_run, mock_build_graph) -> None:
    state = make_state(["agent1"], "report", is_subagent = True)
    new_state = make_output_state(state["agent_order"])
    template = Agent(
        id = "sub",
        max_context_len = 5,
        n_delete = 2,
        chat_models = ["model"],
        summarize_models = ["model"]
    )
    command = SubagentCommand(command = "subagent", prompt = "inspect this", n_agents = 1)

    command.run(state, new_state, [template], MagicMock())

    mock_build_graph.assert_not_called()
    mock_run.assert_not_called()
    assert new_state["agent_contexts"]["updates"]["agent1"]["personal_output"] == "[ERROR] `subagent` is not a valid command for subagents.\n\n"
