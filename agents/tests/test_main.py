import json
from unittest.mock import MagicMock, patch
import pytest
import main
from agents.state import make_initial_state


def make_submission_state() -> dict:
    state = make_initial_state(["agent1"], "generator", "prompt")
    state["proposal_state"] = {
        "state": "submission",
        "type": "generator",
        "submission": {
            "generator": {
                "title": "candidate"
            },
            "search_space": {
                "x": [1, 2]
            }
        }
    }
    state["commands"] = ["submit_experiments"]
    state["params"] = [
        {
            "generator": {
                "title": "candidate"
            },
            "search_space": {
                "x": [1, 2]
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


def test_prompt_submission_decision_reprompts_for_reason() -> None:
    submission = {
        "generator": {},
        "search_space": {}
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


@patch.object(main, "delete_state")
@patch.object(main, "execute_generator", return_value = 8)
@patch.object(main, "prompt_submission_decision", return_value = (True, None))
@patch.object(main, "load_submission")
def test_run_generator_with_human_review_approves_submission(
    mock_load_submission,
    mock_prompt_submission_decision,
    mock_execute_generator,
    mock_delete_state
) -> None:
    submission = {
        "generator": {
            "title": "candidate"
        },
        "search_space": {
            "x": [1, 2]
        }
    }
    mock_load_submission.return_value = submission
    agents = MagicMock()
    redis_client = MagicMock()

    result = main.run_generator_with_human_review(agents, "find strategies", redis_client)

    agents.run.assert_called_once_with("generator", "find strategies")
    mock_prompt_submission_decision.assert_called_once_with(submission)
    mock_execute_generator.assert_called_once_with(
        submission["generator"],
        submission["search_space"],
        redis_client
    )
    mock_delete_state.assert_called_once()
    assert result == 8


@patch.object(main, "delete_state")
@patch.object(main, "execute_generator", return_value = 5)
@patch.object(main, "reject_submission")
@patch.object(main, "prompt_submission_decision")
@patch.object(main, "load_submission")
def test_run_generator_with_human_review_retries_after_rejection(
    mock_load_submission,
    mock_prompt_submission_decision,
    mock_reject_submission,
    mock_execute_generator,
    mock_delete_state
) -> None:
    first_submission = {
        "generator": {
            "title": "first"
        },
        "search_space": {
            "x": [1, 2, 3]
        }
    }
    second_submission = {
        "generator": {
            "title": "second"
        },
        "search_space": {
            "x": [1]
        }
    }
    mock_load_submission.side_effect = [first_submission, second_submission]
    mock_prompt_submission_decision.side_effect = [
        (False, "Search space is too broad"),
        (True, None)
    ]
    agents = MagicMock()
    redis_client = MagicMock()

    result = main.run_generator_with_human_review(agents, "find strategies", redis_client)

    assert agents.run.call_count == 2
    mock_reject_submission.assert_called_once_with("Search space is too broad")
    mock_execute_generator.assert_called_once_with(
        second_submission["generator"],
        second_submission["search_space"],
        redis_client
    )
    mock_delete_state.assert_called_once()
    assert result == 5
