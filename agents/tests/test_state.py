from hypothesis import given, strategies as st
from unittest.mock import patch
from agents.state import *
from composites import mock_agents_state, mock_agent_contexts, mock_context_update
import copy

@given(mock_context_update(), mock_agent_contexts())
def test_update_context(context_update: ContextUpdate, contexts: dict[str, list[Message]]):
    with patch("agents.state.append_update") as append_update, patch("agents.state.new_msg_update") as new_msg_update, patch("agents.state.delete_update") as delete_update:
        append_update.return_value = None
        new_msg_update.return_value = None
        delete_update.return_value = None

        update_context(contexts, context_update)

        if "updates" in context_update:
            append_update.assert_called_once_with(contexts, context_update["updates"])

        if "new_msg" in context_update:
            new_msg_update.assert_called_once_with(contexts, context_update["new_msg"])

        if "delete" in context_update:
            delete_update.assert_called_once_with(contexts, context_update["delete"])

@given(st.dictionaries(keys = st.text(), values = st.text()), st.dictionaries(keys = st.text(), values = st.text()))
def test_update_dict(old: dict[str, str], new: dict[str, str]):
    updated = update_dict(old, new)

    for key, value in new.items():
        assert updated[key] == value

    for key, value in old.items():
        if key not in new:
            assert updated[key] == value

@given(mock_agents_state())
def test_get_agent_id(state: AgentsState):
    agent_id = get_agent_id(state)

    assert agent_id in state["agent_order"]

def output_filter(agent_ids: list[str]) -> bool:

    def inner(state: AgentsState):
        for agent_id in agent_ids:

            if not "updates" in state["agent_contexts"]:
                return False
            
            if not agent_id in state["agent_contexts"]["updates"]:
                return False
            
            if state["agent_contexts"]["updates"][agent_id]["role"] != "user":
                return False

        return True
    
    return inner

@given(st.data(), mock_agents_state(), st.text(), st.booleans())
def test_personal_output(data: st.DataObject, state: AgentsState, content: str, include_agent_id: bool):
    agent_ids = state["agent_order"]
    agent_id = data.draw(st.sampled_from(agent_ids), "agent_id")

    filter_state = output_filter([agent_id])
    new_state = data.draw(mock_agents_state(agent_ids = agent_ids, context_update = True).filter(filter_state), "new_state")

    old_output = new_state["agent_contexts"]["updates"][agent_id]["personal_output"]

    with patch("agents.state.get_agent_id") as get_agent_id:
        get_agent_id.return_value = agent_id

        if include_agent_id:
            personal_output(state, new_state, content, agent_id = agent_id)
            get_agent_id.assert_not_called()

        else:

            personal_output(state, new_state, content)
            get_agent_id.assert_called_once_with(state)
        
        new_output = old_output + content
        assert new_state["agent_contexts"]["updates"][agent_id]["personal_output"] == new_output

@given(st.data(), mock_agents_state(), st.text(), st.booleans())
def test_global_output(data: st.DataObject, state: AgentsState, content: str, ignore_current: bool):
    agent_ids = state["agent_order"]
    curr_agent_id = data.draw(st.sampled_from(agent_ids), "agent_id")

    filter_state = output_filter(agent_ids)
    new_state = data.draw(mock_agents_state(agent_ids = agent_ids, context_update = True).filter(filter_state), "new_state")

    old_outputs = {agent_id: new_state["agent_contexts"]["updates"][agent_id]["global_output"] for agent_id in agent_ids}

    with patch("agents.state.get_agent_id") as get_agent_id:
        get_agent_id.return_value = curr_agent_id

        global_output(state, new_state, content, ignore_current = ignore_current)

        get_agent_id.assert_called_once_with(state)

        for agent_id in agent_ids:
            output_update = new_state["agent_contexts"]["updates"][agent_id]["global_output"]

            if ignore_current and agent_id == curr_agent_id:
                assert output_update == old_outputs[agent_id]
            else:
                assert output_update == old_outputs[agent_id] + content


@given(st.lists(st.text(), min_size = 1, max_size = 5, unique = True), st.text())
def test_make_initial_state(agent_ids: list[str], agent_prompt: str):

    with patch("agents.state.make_agent_prompt") as make_agent_prompt:
        make_agent_prompt.return_value = agent_prompt

        initital_state = make_initial_state(agent_ids)

        assert initital_state["agent_order"] == agent_ids

        for agent_id in agent_ids:
            make_agent_prompt.assert_any_call(agent_ids, agent_id, "", "")

            assert initital_state["system_prompts"][agent_id] == agent_prompt
            assert initital_state["summaries"][agent_id] == ""
            assert initital_state["plans"][agent_id] == ""
            assert len(initital_state["agent_contexts"][agent_id]) == 1

@given(st.data(), mock_agent_contexts())
def test_append_update(data: st.DataObject, contexts: dict[str, list[Message]]):
    
    old_contexts = copy.deepcopy(contexts)
    
    updates = {}
    for agent_id, msgs in contexts.items():
        if not msgs:
            continue
            
        last_msg = msgs[-1]
        role = last_msg.get("role")
        
        valid_keys = []
        if role == "assistant":
            valid_keys = ["model_output"]
        elif role == "user":
            valid_keys = ["personal_output", "global_output"]
            
        if valid_keys and data.draw(st.booleans()):
            keys_to_update = data.draw(st.lists(st.sampled_from(valid_keys), min_size=1, unique=True))
            updates[agent_id] = {k: data.draw(st.text()) for k in keys_to_update}
            
    append_update(contexts, updates)

    for agent_id, update in updates.items():
        for key, text in update.items():
            assert contexts[agent_id][-1][key] == old_contexts[agent_id][-1][key] + text

    for agent_id in contexts:
        if agent_id not in updates:
            assert contexts[agent_id] == old_contexts[agent_id]

@given(st.data(), mock_agent_contexts())
def test_new_msg_update(data: st.DataObject, contexts: dict[str, list[Message]]):
    old_contexts = copy.deepcopy(contexts)
    
    agent_ids = list(contexts.keys())
    new_msg = data.draw(st.dictionaries(
        keys=st.sampled_from(agent_ids),
        values=st.sampled_from(["assistant", "user"])
    ))

    new_msg_update(contexts, new_msg)

    for agent_id, role in new_msg.items():
        assert len(contexts[agent_id]) == len(old_contexts[agent_id]) + 1
        assert contexts[agent_id][-1]["role"] == role
        if role == "assistant":
            assert contexts[agent_id][-1]["model_output"] == ""
        elif role == "user":
            assert contexts[agent_id][-1]["personal_output"] == ""
            assert contexts[agent_id][-1]["global_output"] == ""
            
    for agent_id in contexts:
        if agent_id not in new_msg:
            assert contexts[agent_id] == old_contexts[agent_id]

@given(st.data(), mock_agent_contexts())
def test_delete_update(data: st.DataObject, contexts: dict[str, list[Message]]):
    import copy
    old_contexts = copy.deepcopy(contexts)
    
    agent_ids = list(contexts.keys())
    delete = {}
    for agent_id in agent_ids:
        if data.draw(st.booleans()):
            n_msgs = len(contexts[agent_id])
            delete[agent_id] = data.draw(st.integers(min_value=0, max_value=n_msgs))

    delete_update(contexts, delete)

    for agent_id, n_delete in delete.items():
        assert contexts[agent_id] == old_contexts[agent_id][n_delete:]

    for agent_id in contexts:
        if agent_id not in delete:
            assert contexts[agent_id] == old_contexts[agent_id]

    