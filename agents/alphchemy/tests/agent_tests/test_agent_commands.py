import pytest
from agents.commands import Command, QueryExperimentsCommand
from agents.prompts import build_env
from pydantic import TypeAdapter, ValidationError


def test_query_experiments_command_parses():
    adapter = TypeAdapter(Command)
    payload = {"command": "query_experiments", "query": "select:\n    id"}

    command = adapter.validate_python(payload)

    assert isinstance(command, QueryExperimentsCommand)


def test_analyze_data_command_is_rejected():
    adapter = TypeAdapter(Command)
    payload = {"command": "analyze_data", "query": "select:\n    id"}

    with pytest.raises(ValidationError):
        adapter.validate_python(payload)


def test_prompt_uses_query_experiments_command_name():
    prompt = build_env(False, False)

    assert "query_experiments" in prompt
    assert "analyze_data" not in prompt
