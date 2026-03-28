from unittest.mock import ANY, MagicMock, mock_open, patch
import json
import pytest
from agents.commands import MessageCommand, SubmitExperimentsCommand, SubagentCommand
from agents.nodes import CommandNode, EndTurnNode, LLMNode, StartTurnNode, SummarizeNode, query_llm
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
def mock_redis_client():
    return MagicMock()


@pytest.fixture
def base_state():
    return {
        "agent_order": ["agent1", "agent2"],
        "turn": 0,
        "n_rounds": 0,
        "agent_contexts": {
            "agent1": [
                {"role": "user", "personal_output": "personal", "global_output": "global"},
                {"role": "assistant", "model_output": "assistant"}
            ],
            "agent2": []
        },
        "system_prompts": {
            "agent1": "prompt1",
            "agent2": "prompt2"
        },
        "summaries": {
            "agent1": "summary1",
            "agent2": "summary2"
        },
        "commands": [],
        "params": [],
        "proposal": None,
        "proposal_agent": None,
        "votes": [],
        "experiments_running": False,
        "report": None,
        "done": False,
        "subagent_task": None
    }


def test_query_llm(mock_open_router):
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
@patch("agents.nodes.global_output")
def test_start_turn_node(mock_global_output, mock_get_agent_id, mock_redis_client, base_state):
    mock_get_agent_id.return_value = "agent1"
    mock_redis_client.llen.return_value = 0

    node = StartTurnNode(redis_client = mock_redis_client)
    new_state = node(base_state)

    assert new_state["agent_contexts"]["new_msg"]["agent1"] == "assistant"
    mock_global_output.assert_not_called()

    base_state["experiments_running"] = True
    mock_redis_client.llen.return_value = 0

    new_state = node(base_state)

    assert new_state["experiments_running"] is False
    mock_global_output.assert_any_call(
        base_state,
        ANY,
        "[NOTIFICATION] Experiments have finished running.\n\n",
        ignore_current = False
    )


@patch("agents.nodes.get_agent_id")
def test_llm_node(mock_get_agent_id, mock_open_router, base_state):
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

    mocked_file.assert_called_with("../data/agent1_context.txt", "w")
    assert new_state["commands"] == ["message"]
    assert new_state["params"] == [{"content": "test"}]
    assert new_state["agent_contexts"]["updates"]["agent1"]["model_output"] == response_content
    assert new_state["agent_contexts"]["new_msg"]["agent1"] == "user"


@patch("agents.nodes.get_agent_id")
@patch("agents.nodes.make_agent_prompt")
def test_summarize_node(mock_make_agent_prompt, mock_get_agent_id, mock_open_router, base_state):
    mock_get_agent_id.return_value = "agent1"
    mock_make_agent_prompt.return_value = "new prompt"

    models = {"agent1": ["model1"]}
    n_delete = {"agent1": 1}
    node = SummarizeNode(open_router = mock_open_router, models = models, n_delete = n_delete)

    mock_open_router.chat.send.return_value.choices[0].message.content = "new summary"
    new_state = node(base_state)

    assert new_state["summaries"]["agent1"] == "new summary"
    assert new_state["agent_contexts"]["delete"]["agent1"] == 1
    assert new_state["system_prompts"]["agent1"] == "new prompt"


@patch("agents.nodes.TypeAdapter")
@patch("agents.nodes.personal_output")
def test_command_node_handles_empty_commands(mock_personal_output, mock_type_adapter, mock_redis_client, mock_open_router, base_state):
    node = CommandNode(
        redis_client = mock_redis_client,
        open_router = mock_open_router,
        subagent_pool = []
    )

    new_state = node(base_state)

    mock_personal_output.assert_called_once()
    mock_type_adapter.assert_not_called()
    assert new_state["commands"] == []


@patch("agents.nodes.TypeAdapter")
def test_command_node_dispatches_submit(mock_type_adapter, mock_redis_client, mock_open_router, base_state):
    node = CommandNode(
        redis_client = mock_redis_client,
        open_router = mock_open_router,
        subagent_pool = []
    )
    command = SubmitExperimentsCommand(
        command = "submit_experiments",
        generator = {},
        search_space = {}
    )
    base_state["commands"] = ["submit_experiments"]
    base_state["params"] = [{"generator": {}, "search_space": {}}]
    mock_type_adapter.return_value.validate_python.return_value = command

    with patch.object(SubmitExperimentsCommand, "run", autospec = True) as mock_run:
        new_state = node(base_state)

    mock_run.assert_called_once_with(command, base_state, new_state, mock_redis_client)


@patch("agents.nodes.TypeAdapter")
def test_command_node_dispatches_subagent(mock_type_adapter, mock_redis_client, mock_open_router, base_state):
    node = CommandNode(
        redis_client = mock_redis_client,
        open_router = mock_open_router,
        subagent_pool = ["template"]
    )
    command = SubagentCommand(command = "subagent", task = "inspect", n_agents = 1)
    base_state["commands"] = ["subagent"]
    base_state["params"] = [{"task": "inspect", "n_agents": 1}]
    mock_type_adapter.return_value.validate_python.return_value = command

    with patch.object(SubagentCommand, "run", autospec = True) as mock_run:
        new_state = node(base_state)

    mock_run.assert_called_once_with(command, base_state, new_state, ["template"], mock_open_router, mock_redis_client)


@patch("agents.nodes.TypeAdapter")
def test_command_node_dispatches_generic_command(mock_type_adapter, mock_redis_client, mock_open_router, base_state):
    node = CommandNode(
        redis_client = mock_redis_client,
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


@patch("agents.nodes.Overwrite", side_effect = lambda value: value)
@patch("agents.nodes.global_output")
def test_end_turn_node(mock_global_output, _mock_overwrite, mock_redis_client, base_state):
    node = EndTurnNode(redis_client = mock_redis_client)

    new_state = node(base_state)
    assert new_state["turn"] == 1

    base_state["turn"] = 1
    new_state = node(base_state)
    assert new_state["turn"] == 0
    assert new_state["n_rounds"] == 1

    base_state["turn"] = 0
    base_state["proposal"] = json.dumps({"generator": {}, "search_space": {}})
    base_state["proposal_agent"] = "agent2"
    base_state["votes"] = ["agent1"]

    new_state = node(base_state)

    assert new_state["proposal"] is None
    assert new_state["proposal_agent"] is None
    assert new_state["votes"] == []
    assert "Vote has not passed" in mock_global_output.call_args[0][2]


@patch("agents.nodes.Overwrite", side_effect = lambda value: value)
@patch("agents.nodes.execute_generator", return_value = 2)
@patch("agents.nodes.global_output")
def test_end_turn_node_submits_experiments(mock_global_output, mock_execute_generator, _mock_overwrite, mock_redis_client, base_state):
    node = EndTurnNode(redis_client = mock_redis_client)

    base_state["proposal"] = json.dumps({"generator": {}, "search_space": {}})
    base_state["proposal_agent"] = "agent2"
    base_state["votes"] = ["agent1", "agent2"]

    new_state = node(base_state)

    mock_execute_generator.assert_called_once_with({}, {}, mock_redis_client)
    assert new_state["experiments_running"] is True
    assert new_state["done"] is True
    assert "Vote has passed" in mock_global_output.call_args[0][2]
