### VIBE CODED, rewrite later

import pytest
from unittest.mock import MagicMock, patch, mock_open, ANY
import json
import redis
from agents.nodes import (
    query_llm,
    StartTurnNode,
    LLMNode,
    PlanNode,
    SummarizeNode,
    CommandNode,
    EndTurnNode
)
from agents.commands import TraverseCommand
from openrouter.components import SystemMessage, UserMessage, AssistantMessage

@pytest.fixture
def mock_open_router():
    router = MagicMock()
    # Setup default response structure
    message = MagicMock()
    message.content = "{}"
    choice = MagicMock()
    choice.message = message
    router.chat.send.return_value.choices = [choice]
    router.chat.send.return_value.model = "test-model"
    return router

@pytest.fixture
def mock_redis_client():
    return MagicMock(spec=redis.Redis)

@pytest.fixture
def mock_updater():
    return MagicMock()

@pytest.fixture
def base_state():
    return {
        "agent_order": ["agent1", "agent2"],
        "turn": 0,
        "n_rounds": 0,
        "agent_contexts": {
            "agent1": [
                {"role": "user", "personal_output": "p", "global_output": "g"},
                {"role": "assistant", "model_output": "m"}
            ],
            "agent2": [],
            "updates": {},
            "new_msg": {}
        },
        "system_prompts": {
            "agent1": "prompt1",
            "agent2": "prompt2"
        },
        "experiments_running": False,
        "plan_counters": {"agent1": 0, "agent2": 0},
        "plans": {"agent1": "plan1", "agent2": "plan2"},
        "summaries": {"agent1": "summary1", "agent2": "summary2"},
        "commands": [],
        "params": [],
        "proposal": None,
        "proposal_agent": None,
        "votes": [],
    }

def test_query_llm(mock_open_router):
    context = [SystemMessage(content="test")]
    models = ["model1"]
    
    # Test JSON mode
    mock_open_router.chat.send.return_value.choices[0].message.content = '{"key": "value"}'
    result = query_llm(mock_open_router, models, context, json_mode=True)
    
    assert result == '{"key": "value"}'
    mock_open_router.chat.send.assert_called_with(
        messages=context,
        models=models,
        response_format={"type": "json_object"},
        timeout_ms=60000
    )

    # Test Text mode
    result = query_llm(mock_open_router, models, context, json_mode=False)
    mock_open_router.chat.send.assert_called_with(
        messages=context,
        models=models,
        response_format={"type": "text"},
        timeout_ms=60000
    )

@patch("agents.nodes.get_agent_id")
@patch("agents.nodes.global_output")
def test_start_turn_node(mock_global_output, mock_get_agent_id, mock_redis_client, mock_updater, base_state):
    mock_get_agent_id.return_value = "agent1"
    node = StartTurnNode(redis_client=mock_redis_client, updater=mock_updater)
    
    # Case 1: Normal start
    mock_updater.check_rebuilt.return_value = False
    mock_redis_client.llen.return_value = 1 
    
    new_state = node(base_state)
    
    assert "agent_contexts" in new_state
    assert new_state["agent_contexts"]["new_msg"]["agent1"] == "assistant"
    mock_global_output.assert_not_called()

    # Case 2: Ontology rebuilt
    mock_updater.check_rebuilt.return_value = True
    node(base_state)
    mock_global_output.assert_any_call(base_state, ANY, "[NOTIFICATION] Ontology has been rebuilt.\n\n", ignore_current=False)

    # Case 3: Experiments finished
    base_state["experiments_running"] = True
    mock_redis_client.llen.return_value = 0
    mock_updater.check_rebuilt.return_value = False
    
    new_state = node(base_state)
    assert new_state["experiments_running"] is False
    mock_global_output.assert_called_with(base_state, ANY, "[NOTIFICATION] Experiments have finished running.\n\n", ignore_current=False)

@patch("agents.nodes.get_agent_id")
def test_llm_node(mock_get_agent_id, mock_open_router, base_state):
    mock_get_agent_id.return_value = "agent1"
    models = {"agent1": ["model1"]}
    node = LLMNode(open_router=mock_open_router, models=models)
    
    # Mock LLM response
    response_content = json.dumps({
        "commands": [
            {"command": "TestCommand", "arg": 1}
        ]
    })
    mock_open_router.chat.send.return_value.choices[0].message.content = response_content
    
    with patch("builtins.open", mock_open()) as mocked_file:
        new_state = node(base_state)
        
        # Check file writing
        mocked_file.assert_called_with("../data/agent1_context.txt", "w")
        
        # Check output parsing
        assert new_state["commands"] == ["TestCommand"]
        assert new_state["params"] == [{"arg": 1}]
        assert new_state["agent_contexts"]["updates"]["agent1"]["model_output"] == response_content
        assert new_state["agent_contexts"]["new_msg"]["agent1"] == "user"

@patch("agents.nodes.get_agent_id")
@patch("agents.nodes.make_planner_prompt")
@patch("agents.nodes.make_agent_prompt")
@patch("agents.nodes.format_messages")
def test_plan_node(mock_fmt, mock_make_agent, mock_make_planner, mock_get_agent_id, mock_open_router, base_state):
    mock_get_agent_id.return_value = "agent1"
    models = {"agent1": ["model1"]}
    plan_freq = {"agent1": 2}
    node = PlanNode(open_router=mock_open_router, models=models, plan_freq=plan_freq)
    
    # Case 1: Counter < Freq
    base_state["plan_counters"]["agent1"] = 0
    new_state = node(base_state)
    assert new_state["plan_counters"]["agent1"] == 1
    mock_open_router.chat.send.assert_not_called()
    
    # Case 2: Counter >= Freq, Plan Incomplete
    base_state["plan_counters"]["agent1"] = 2
    mock_open_router.chat.send.return_value.choices[0].message.content = "PLAN_INCOMPLETE"
    new_state = node(base_state)
    assert new_state == {}
    
    # Case 3: Counter >= Freq, New Plan
    mock_open_router.chat.send.return_value.choices[0].message.content = "New Plan Content"
    mock_make_agent.return_value = "New System Prompt"
    
    new_state = node(base_state)
    assert new_state["plans"]["agent1"] == "New Plan Content"
    assert new_state["system_prompts"]["agent1"] == "New System Prompt"
    assert new_state["plan_counters"]["agent1"] == 0

@patch("agents.nodes.get_agent_id")
@patch("agents.nodes.make_agent_prompt")
@patch("agents.nodes.format_messages")
def test_summarize_node(mock_fmt, mock_make_agent, mock_get_agent_id, mock_open_router, base_state):
    mock_get_agent_id.return_value = "agent1"
    models = {"agent1": ["model1"]}
    n_delete = {"agent1": 5}
    node = SummarizeNode(open_router=mock_open_router, models=models, n_delete=n_delete)
    
    mock_open_router.chat.send.return_value.choices[0].message.content = "New Summary"
    mock_make_agent.return_value = "New System Prompt"
    
    new_state = node(base_state)
    
    assert new_state["summaries"]["agent1"] == "New Summary"
    assert new_state["agent_contexts"]["delete"]["agent1"] == 5
    assert new_state["system_prompts"]["agent1"] == "New System Prompt"

@patch("agents.nodes.TypeAdapter")
@patch("agents.nodes.personal_output")
def test_command_node(mock_personal_output, mock_type_adapter, mock_updater, base_state):
    node = CommandNode(updater=mock_updater)
    
    # Case 1: No commands
    base_state["commands"] = []
    new_state = node(base_state)
    mock_personal_output.assert_called()
    
    # Case 2: Execute normal command
    base_state["commands"] = ["TestCommand"]
    base_state["params"] = [{"arg": 1}]
    
    mock_command_instance = MagicMock()
    mock_type_adapter.return_value.validate_python.return_value = mock_command_instance
    
    new_state = node(base_state)
    
    mock_command_instance.run.assert_called_with(base_state, new_state)
    assert new_state["commands"] == [] 
    
    # Case 3: Execute TraverseCommand (requires updater)
    # Setup mock to pass isinstance check for TraverseCommand
    mock_traverse_instance = MagicMock(spec=TraverseCommand)
    mock_type_adapter.return_value.validate_python.return_value = mock_traverse_instance
    
    base_state["commands"] = ["Traverse"]
    base_state["params"] = [{}]
    
    node(base_state)
    mock_traverse_instance.run.assert_called_with(base_state, ANY, mock_updater)

    # Case 4: Exception during execution
    mock_command_instance.run.side_effect = Exception("Run Error")
    mock_type_adapter.return_value.validate_python.return_value = mock_command_instance
    
    node(base_state)
    assert mock_personal_output.call_count >= 2

@patch("agents.nodes.Overwrite")
@patch("agents.nodes.global_output")
def test_end_turn_node(mock_global_output, mock_overwrite, mock_redis_client, base_state):
    node = EndTurnNode(redis_client=mock_redis_client)
    
    # Case 1: Simple turn update
    base_state["turn"] = 0
    base_state["agent_order"] = ["agent1", "agent2"]
    new_state = node(base_state)
    assert new_state["turn"] == 1
    
    # Case 2: Round update
    base_state["turn"] = 1
    new_state = node(base_state)
    assert new_state["turn"] == 0
    assert new_state["n_rounds"] == 1
    
    # Case 3: Voting - Not passed
    base_state["proposal"] = "some script"
    base_state["proposal_agent"] = "agent2"
    base_state["turn"] = 0 # Next turn is 1 (agent2), so it is last agent
    base_state["votes"] = ["agent1"] # 1 vote out of 2 (50%, not > 50%)
    
    new_state = node(base_state) 
    
    assert new_state["proposal"] is None
    assert "Vote has not passed" in mock_global_output.call_args[0][2]
    
    # Case 4: Voting - Passed
    base_state["turn"] = 0
    base_state["votes"] = ["agent1", "agent2"] # 2 votes > 1
    
    # Script execution mock
    script = """
```python
def generate_experiments():
    return [{"exp": 1}]
```
"""
    base_state["proposal"] = script
    
    new_state = node(base_state)
    
    assert new_state["experiments_running"] is True
    assert "Vote has passed" in mock_global_output.call_args[0][2]
    mock_redis_client.lpush.assert_called()