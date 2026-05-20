import pytest
from pydantic import ValidationError

from agents.commands import SubmitExperimentCommand, SubmitNotebookCommand
from agents.prompts import EXPERIMENT_SCHEMA, EXPERIMENT_DOC_TEMPLATE, EXPERIMENT_SCHEMA_TEMPLATE


def test_experiment_command_payload_wraps_experiment() -> None:
    command = SubmitExperimentCommand(
        command = "submit_experiment",
        title = "Test Experiment",
        experiment = {"val_size": 0.2}
    )

    assert command.payload() == {"title": "Test Experiment", "experiment": {"val_size": 0.2}}


def test_iso_timestamps_are_converted_to_epoch_seconds() -> None:
    command = SubmitExperimentCommand(
        command = "submit_experiment",
        title = "x",
        experiment = {
            "val_size": 0.2,
            "start_timestamp": "2024-01-01T00:00:00Z",
            "end_timestamp": "2024-02-01T00:00:00Z"
        }
    )
    payload = command.payload()
    experiment = payload["experiment"]
    assert isinstance(experiment["start_timestamp"], float)
    assert experiment["start_timestamp"] == 1704067200.0
    assert experiment["end_timestamp"] == 1706745600.0


def test_notebook_command_requires_query_ids() -> None:
    with pytest.raises(ValidationError):
        SubmitNotebookCommand(
            command = "submit_notebook",
            title = "Notebook",
            queries = [
                {
                    "select": ["results.mean.test_results.excess_sharpe"],
                    "filters": []
                }
            ],
            notes = {"query-1": "summary"},
            layout = {
                "left": ["query-1"],
                "right": []
            }
        )


def test_notebook_command_payload_keeps_query_ids() -> None:
    command = SubmitNotebookCommand(
        command = "submit_notebook",
        title = "Notebook",
        queries = [
            {
                "id": "query-1",
                "select": ["results.mean.test_results.excess_sharpe"],
                "filters": []
            }
        ],
        notes = {"query-1": "summary"},
        layout = {
            "left": [],
            "right": []
        }
    )

    payload = command.payload()

    assert payload["queries"][0]["id"] == "query-1"
    assert payload["notes"] == {"query-1": "summary"}


def test_prompt_no_longer_references_generator_machinery() -> None:
    assert "param_space" not in EXPERIMENT_DOC_TEMPLATE
    assert "param_space" not in EXPERIMENT_SCHEMA_TEMPLATE
    assert "param key" not in EXPERIMENT_SCHEMA.lower()
    assert "search_space" not in EXPERIMENT_SCHEMA
    assert "_pool" not in EXPERIMENT_SCHEMA


def test_prompt_no_longer_documents_experiment_title() -> None:
    assert "\"title\"" not in EXPERIMENT_SCHEMA


def test_prompt_uses_runner_compatible_flat_strategy_objects() -> None:
    assert "logic_net" not in EXPERIMENT_SCHEMA
    assert "decision_net" not in EXPERIMENT_SCHEMA
    assert "logic_actions" not in EXPERIMENT_SCHEMA
    assert "decision_actions" not in EXPERIMENT_SCHEMA
    assert "logic_penalties" not in EXPERIMENT_SCHEMA
    assert "decision_penalties" not in EXPERIMENT_SCHEMA
    assert "merge field" not in EXPERIMENT_SCHEMA.lower()
    assert '"type": "logic"' in EXPERIMENT_SCHEMA
    assert '"type": "decision"' in EXPERIMENT_SCHEMA


def test_prompt_documents_indicator_features() -> None:
    for feature_name in [
        "constant",
        "raw_returns",
        "normalized_sma",
        "normalized_ema",
        "normalized_macd",
        "rsi",
        "normalized_bb",
        "stochastic",
        "normalized_atr",
        "roc",
        "normalized_dc"
    ]:
        assert feature_name in EXPERIMENT_SCHEMA
