import json
from unittest.mock import MagicMock, patch
import pytest
import main
from agents.state import make_initial_state


def make_submission_state() -> dict:
    state = make_initial_state(["agent1"], "prompt")
    state["proposal_state"] = {
        "state": "submission",
        "type": "generator",
        "submission": {
            "generator": {
                "title": "candidate"
            },
            "param_space": {
                "search_space": {
                    "x": [1, 2]
                }
            }
        }
    }
    state["commands"] = ["submit_experiments"]
    state["params"] = [
        {
            "generator": {
                "title": "candidate"
            },
            "param_space": {
                "search_space": {
                    "x": [1, 2]
                }
            }
        }
    ]
    return state


def test_reject_submission_persists_rejection_state(tmp_path, monkeypatch) -> None:
    state_path = tmp_path / "state.json"
    state = make_submission_state()
    state_path.write_text(json.dumps(state))
    monkeypatch.setattr(main, "STATE_PATH", str(state_path))

    main.reject_submission("Needs tighter bounds")

    saved_state = json.loads(state_path.read_text())

    assert saved_state["proposal_state"] == {
        "state": "rejection",
        "reason": "Needs tighter bounds"
    }
    assert saved_state["commands"] == []
    assert saved_state["params"] == []


def test_reject_submission_requires_reason(tmp_path, monkeypatch) -> None:
    state_path = tmp_path / "state.json"
    state = make_submission_state()
    state_path.write_text(json.dumps(state))
    monkeypatch.setattr(main, "STATE_PATH", str(state_path))

    with pytest.raises(ValueError):
        main.reject_submission("   ")


def test_approve_submission_resets_to_idle(tmp_path, monkeypatch) -> None:
    state_path = tmp_path / "state.json"
    state = make_submission_state()
    state_path.write_text(json.dumps(state))
    monkeypatch.setattr(main, "STATE_PATH", str(state_path))

    main.approve_submission()

    saved_state = json.loads(state_path.read_text())

    assert saved_state["proposal_state"] == {"state": "idle"}
    assert saved_state["commands"] == []
    assert saved_state["params"] == []


def test_prompt_submission_decision_reprompts_for_reason() -> None:
    submission = {
        "generator": {},
        "param_space": {
            "search_space": {}
        }
    }

    with patch("builtins.input", side_effect = ["r", "", "Use fewer parameters"]):
        with patch("builtins.print") as mock_print:
            approved, reason = main.prompt_submission_decision(submission)

    assert approved is False
    assert reason == "Use fewer parameters"
    assert any(
        call.args[0] == "Rejection reason cannot be empty."
        for call in mock_print.call_args_list
    )


@patch.object(main, "approve_submission")
@patch.object(main, "prompt_submission_decision")
def test_run_with_review_approves_generator_submission(
    mock_prompt,
    mock_approve
) -> None:
    submission = {
        "generator": {"title": "candidate"},
        "param_space": {"search_space": {"x": [1, 2]}}
    }
    agents = MagicMock()
    agents.run.side_effect = [
        {"state": "submission", "type": "generator", "submission": submission},
        KeyboardInterrupt
    ]
    mock_prompt.return_value = (True, None)

    with pytest.raises(KeyboardInterrupt):
        main.run_with_review(agents, "find strategies")

    agents.run.assert_any_call("find strategies")
    mock_prompt.assert_called_once_with(submission)
    mock_approve.assert_called_once()


@patch.object(main, "approve_submission")
@patch.object(main, "reject_submission")
@patch.object(main, "prompt_submission_decision")
def test_run_with_review_retries_after_rejection(
    mock_prompt,
    mock_reject,
    mock_approve
) -> None:
    first_submission = {
        "generator": {"title": "first"},
        "param_space": {"search_space": {"x": [1, 2, 3]}}
    }
    second_submission = {
        "generator": {"title": "second"},
        "param_space": {"search_space": {"x": [1]}}
    }
    agents = MagicMock()
    agents.run.side_effect = [
        {"state": "submission", "type": "generator", "submission": first_submission},
        {"state": "submission", "type": "generator", "submission": second_submission},
        KeyboardInterrupt
    ]
    mock_prompt.side_effect = [
        (False, "Search space is too broad"),
        (True, None)
    ]

    with pytest.raises(KeyboardInterrupt):
        main.run_with_review(agents, "find strategies")

    assert agents.run.call_count == 3
    mock_reject.assert_called_once_with("Search space is too broad")
    mock_approve.assert_called_once()


@patch.object(main, "approve_submission")
@patch.object(main, "prompt_submission_decision")
def test_run_with_review_handles_report_submission(
    mock_prompt,
    mock_approve
) -> None:
    submission = {"report": "findings here"}
    agents = MagicMock()
    agents.run.side_effect = [
        {"state": "submission", "type": "report", "submission": submission},
        KeyboardInterrupt
    ]
    mock_prompt.return_value = (True, None)

    with pytest.raises(KeyboardInterrupt):
        main.run_with_review(agents, "investigate")

    mock_prompt.assert_called_once_with(submission)
    mock_approve.assert_called_once()
