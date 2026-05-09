from agents.commands import SubmitExperimentCommand
from agents.prompts import EXPERIMENT_SCHEMA, EXPERIMENT_DOC_TEMPLATE, EXPERIMENT_SCHEMA_TEMPLATE
from main import submit_experiment


def test_submit_experiment_is_stub() -> None:
    assert submit_experiment({"experiment": {"val_size": 0.2}}) is None


def test_experiment_command_payload_wraps_experiment() -> None:
    command = SubmitExperimentCommand(
        command = "submit_experiment",
        experiment = {"val_size": 0.2}
    )

    assert command.payload() == {"experiment": {"val_size": 0.2}}


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
