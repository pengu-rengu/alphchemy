import json
from pathlib import Path

from agents.commands import SubmitExperimentsCommand
from agents.prompts import EXPERIMENT_GENERATOR, EXPERIMENTS_DOC_TEMPLATE, EXPERIMENTS_SCHEMA_TEMPLATE
from main import execute_generator


FIXTURE_PATH = Path(__file__).resolve().parents[1] / "src" / "generator.json"


def load_submission() -> dict:
    with open(FIXTURE_PATH, "r") as file:
        return json.load(file)


def test_execute_generator_writes_generated_batch(tmp_path: Path) -> None:
    submission = load_submission()
    output_path = tmp_path / "generated.jsonl"

    count = execute_generator(submission, output_path)

    with open(output_path, "r") as file:
        lines = file.readlines()

    assert count == 1000
    assert len(lines) == count


def test_experiments_command_payload_uses_search_space() -> None:
    command = SubmitExperimentsCommand(
        command = "submit_experiments",
        generator = {"title": "alpha"},
        search_space = {"folds": [3, 5]}
    )

    assert command.payload() == {
        "generator": {"title": "alpha"},
        "search_space": {"folds": [3, 5]}
    }


def test_prompt_examples_match_runtime_contract() -> None:
    assert "param_space" not in EXPERIMENTS_DOC_TEMPLATE
    assert "param_space" not in EXPERIMENTS_SCHEMA_TEMPLATE
    assert '{"key": "param_name"}' not in EXPERIMENT_GENERATOR
    assert '{"param": "param_name"}' in EXPERIMENT_GENERATOR
