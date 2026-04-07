from unittest.mock import MagicMock, mock_open, patch
import json
import pytest
from agents.commands import MessageCommand, SubmitExperimentsCommand, SubagentCommand
from agents.data_paths import agent_context_path
from agents.nodes import CommandNode, EndTurnNode, LLMNode, StartTurnNode, SummarizeNode, query_llm
from agents.state import make_initial_state
from openrouter.components import SystemMessage


@pytest.fixture
def mock_open_router():
    router = MagicMock()
    message = MagicMock()
    message.content = "{}"
    choice = MagicMock()
    choice.message = message
    router.chat.send.return_value.choices = [choice]
    router.chat.send.return_value.model = "test-model"
    return router


@pytest.fixture
def base_state():
    state = make_initial_state(["agent1", "agent2"], "main prompt")
    state["agent_contexts"] = {
        "agent1": [
            {"role": "user", "personal_output": "personal", "global_output": "global"},
            {"role": "assistant", "model_output": "assistant"}
        ],
        "agent2": []
    }
    state["system_prompts"] = {
        "agent1": "prompt1",
        "agent2": "prompt2"
    }
    state["summaries"] = {
        "agent1": "summary1",
        "agent2": "summary2"
    }
    return state


def test_query_llm(mock_open_router) -> None:
    context = [SystemMessage(content = "test")]
    models = ["model1"]

    mock_open_router.chat.send.return_value.choices[0].message.content = "{\"key\": \"value\"}"
    result = query_llm(mock_open_router, models, context)

    assert result == "{\"key\": \"value\"}"
    mock_open_router.chat.send.assert_called_with(
        messages = context,
        models = models,
        response_format = {"type": "json_object"},
        timeout_ms = 60 * 1000
    )


@patch("agents.nodes.get_agent_id")
def test_start_turn_node(mock_get_agent_id, base_state) -> None:
    mock_get_agent_id.return_value = "agent1"

    node = StartTurnNode()
    new_state = node(base_state)

    assert new_state["agent_contexts"]["new_msg"]["agent1"] == "assistant"


@patch("agents.nodes.get_agent_id")
def test_start_turn_node_consumes_rejection(mock_get_agent_id, base_state) -> None:
    mock_get_agent_id.return_value = "agent1"
    base_state["proposal_state"] = {
        "state": "rejection",
        "reason": "Search space is too broad."
    }

    node = StartTurnNode()
    new_state = node(base_state)

    rejection_text = "[HUMAN REJECTION]\nReason: Search space is too broad.\n\nRevise the generator submission and resubmit."

    assert new_state["proposal_state"] == {
        "state": "idle"
    }
    assert new_state["agent_contexts"]["append_msgs"]["agent1"] == [
        {
            "role": "user",
            "personal_output": rejection_text,
            "global_output": ""
        },
        {
            "role": "assistant",
            "model_output": ""
        }
    ]
    assert new_state["agent_contexts"]["append_msgs"]["agent2"] == [
        {
            "role": "user",
            "personal_output": rejection_text,
            "global_output": ""
        }
    ]


@patch("agents.nodes.get_agent_id")
def test_llm_node(mock_get_agent_id, mock_open_router, base_state) -> None:
    mock_get_agent_id.return_value = "agent1"
    models = {"agent1": ["model1"]}
    node = LLMNode(open_router = mock_open_router, models = models)

    response_content = json.dumps({
        "commands": [
            {"command": "message", "content": "test"}
        ]
    })
    mock_open_router.chat.send.return_value.choices[0].message.content = response_content

    with patch("builtins.open", mock_open()) as mocked_file:
        new_state = node(base_state)

    mocked_file.assert_called_with(agent_context_path("agent1"), "w")
    assert new_state["commands"] == ["message"]
    assert new_state["params"] == [{"content": "test"}]
    assert new_state["agent_contexts"]["updates"]["agent1"]["model_output"] == response_content
    assert new_state["agent_contexts"]["new_msg"]["agent1"] == "user"


@patch("agents.nodes.get_agent_id")
@patch("agents.nodes.make_agent_prompt")
def test_summarize_node(mock_make_agent_prompt, mock_get_agent_id, mock_open_router, base_state) -> None:
    mock_get_agent_id.return_value = "agent1"
    mock_make_agent_prompt.return_value = "new prompt"

    models = {"agent1": ["model1"]}
    n_delete = {"agent1": 1}
    node = SummarizeNode(open_router = mock_open_router, models = models, n_delete = n_delete, prompt = "runtime prompt")

    mock_open_router.chat.send.return_value.choices[0].message.content = "new summary"
    new_state = node(base_state)

    mock_make_agent_prompt.assert_called_once_with(
        ["agent1", "agent2"],
        "agent1",
        "runtime prompt",
        "new summary",
        False
    )
    assert new_state["summaries"]["agent1"] == "new summary"
    assert new_state["agent_contexts"]["delete"]["agent1"] == 1
    assert new_state["system_prompts"]["agent1"] == "new prompt"


@patch("agents.nodes.TypeAdapter")
@patch("agents.nodes.personal_output")
def test_command_node_handles_empty_commands(mock_personal_output, mock_type_adapter, mock_open_router, base_state) -> None:
    node = CommandNode(
        open_router = mock_open_router,
        subagent_pool = []
    )

    new_state = node(base_state)

    mock_personal_output.assert_called_once()
    mock_type_adapter.assert_not_called()
    assert new_state["commands"] == []


@patch("agents.nodes.TypeAdapter")
def test_command_node_dispatches_submit(mock_type_adapter, mock_open_router, base_state) -> None:
    node = CommandNode(
        open_router = mock_open_router,
        subagent_pool = []
    )
    command = SubmitExperimentsCommand(
        command = "submit_experiments",
        generator = {},
        param_space = {"search_space": {}}
    )
    base_state["commands"] = ["submit_experiments"]
    base_state["params"] = [{"generator": {}, "param_space": {"search_space": {}}}]
    mock_type_adapter.return_value.validate_python.return_value = command

    with patch.object(SubmitExperimentsCommand, "run", autospec = True) as mock_run:
        new_state = node(base_state)

    mock_run.assert_called_once_with(command, base_state, new_state)


@patch("agents.nodes.TypeAdapter")
def test_command_node_dispatches_subagent(mock_type_adapter, mock_open_router, base_state) -> None:
    node = CommandNode(
        open_router = mock_open_router,
        subagent_pool = ["template"]
    )
    command = SubagentCommand(command = "subagent", prompt = "inspect", n_agents = 1)
    base_state["commands"] = ["subagent"]
    base_state["params"] = [{"prompt": "inspect", "n_agents": 1}]
    mock_type_adapter.return_value.validate_python.return_value = command

    with patch.object(SubagentCommand, "run", autospec = True) as mock_run:
        new_state = node(base_state)

    mock_run.assert_called_once_with(command, base_state, new_state, ["template"], mock_open_router)


@patch("agents.nodes.TypeAdapter")
def test_command_node_dispatches_generic_command(mock_type_adapter, mock_open_router, base_state) -> None:
    node = CommandNode(
        open_router = mock_open_router,
        subagent_pool = []
    )
    command = MessageCommand(command = "message", content = "hello")
    base_state["commands"] = ["message"]
    base_state["params"] = [{"content": "hello"}]
    mock_type_adapter.return_value.validate_python.return_value = command

    with patch.object(MessageCommand, "run", autospec = True) as mock_run:
        new_state = node(base_state)

    mock_run.assert_called_once_with(command, base_state, new_state)


def test_end_turn_node_updates_turn_and_round(base_state) -> None:
    node = EndTurnNode()

    new_state = node(base_state)
    assert new_state["turn"] == 1

    base_state["turn"] = 1
    new_state = node(base_state)
    assert new_state["turn"] == 0

@patch("agents.nodes.global_output")
def test_end_turn_node_closes_failed_vote_to_idle(mock_global_output, base_state) -> None:
    node = EndTurnNode()

    base_state["proposal_state"] = {
        "state": "proposal",
        "type": "generator",
        "proposal": {
            "generator": {},
            "param_space": {
                "search_space": {}
            }
        },
        "agent_id": "agent2",
        "votes": ["agent2"]
    }

    new_state = node(base_state)

    assert new_state["proposal_state"] == {
        "state": "idle"
    }
    assert "Vote has not passed" in mock_global_output.call_args[0][2]


@patch("agents.nodes.global_output")
def test_end_turn_node_submits_proposal_on_majority(mock_global_output, base_state) -> None:
    node = EndTurnNode()

    base_state["proposal_state"] = {
        "state": "proposal",
        "type": "generator",
        "proposal": {
            "generator": {},
            "param_space": {
                "search_space": {}
            }
        },
        "agent_id": "agent2",
        "votes": ["agent1", "agent2"]
    }

    new_state = node(base_state)

    assert new_state["proposal_state"] == {
        "state": "submission",
        "type": "generator",
        "submission": {
            "generator": {},
            "param_space": {
                "search_space": {}
            }
        }
    }
    assert "Vote has passed" in mock_global_output.call_args[0][2]
