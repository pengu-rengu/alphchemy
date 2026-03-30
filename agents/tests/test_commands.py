from agents.commands import ProposeExperimentsCommand, SubmitExperimentsCommand, SubmitReportCommand, VoteCommand
from agents.state import make_initial_state


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


def test_propose_experiments_command_sets_proposal_state() -> None:
    state = make_initial_state(["agent1", "agent2"])
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
    state = make_initial_state(["agent1"])
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
    state = make_initial_state(["agent1"])
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
    state = make_initial_state(["agent1", "agent2"])
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
