import pytest
from agents.commands import AnalyzeDataCommand
from agents.state import make_initial_state
from analysis.filters import NumericFilter
from pydantic import ValidationError
from unittest.mock import patch


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


def test_analyze_data_command_uses_query_experiments() -> None:
    state = make_initial_state(["agent1"], "prompt")
    new_state = make_output_state(state["agent_order"])
    command = AnalyzeDataCommand(
        command = "analyze_data",
        select = ["results.overall_excess_sharpe"],
        filters = [[{
            "type": "numeric",
            "path": "results.overall_excess_sharpe",
            "gte": 0.4
        }]]
    )

    with patch("agents.commands.query_experiments", return_value = "[QUERY] 1 matched\n\n") as mock_query:
        command.run(state, new_state)

    mock_query.assert_called_once()

    called_filters = mock_query.call_args.kwargs["filter_groups"]
    called_filter = called_filters[0][0]

    assert isinstance(called_filter, NumericFilter)
    assert called_filter.gte == 0.4
    assert new_state["agent_contexts"]["updates"]["agent1"]["personal_output"] == "[QUERY] 1 matched\n\n"


def test_analyze_data_command_requires_select() -> None:
    with pytest.raises(ValidationError):
        AnalyzeDataCommand(
            command = "analyze_data",
            select = []
        )


def test_analyze_data_command_reports_missing_file() -> None:
    state = make_initial_state(["agent1"], "prompt")
    new_state = make_output_state(state["agent_order"])
    command = AnalyzeDataCommand(
        command = "analyze_data",
        select = ["results.overall_excess_sharpe"]
    )

    with patch("agents.commands.query_experiments", side_effect = FileNotFoundError):
        command.run(state, new_state)

    assert "Could not find experiments data." in new_state["agent_contexts"]["updates"]["agent1"]["personal_output"]
