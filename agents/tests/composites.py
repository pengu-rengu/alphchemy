from agents.state import AgentsState, ContextUpdate, Message, make_initial_state
from hypothesis import strategies as st
from typing import Literal

@st.composite
def mock_dict(draw, agent_ids: list[str]) -> dict[str, str]:
    return {agent_id: draw(st.text()) for agent_id in agent_ids}

@st.composite
def mock_message(draw, role: Literal["assistant", "user"] | None = None) -> Message:
    if not role:
        role = draw(st.sampled_from(["assistant", "user"]))

    if role == "assistant":
        model_output = draw(st.text())

        return {
            "role": "assistant",
            "model_output": model_output,
        }
    elif role == "user":
        personal_output = draw(st.text())
        global_output = draw(st.text())
        
        return {
            "role": "user",
            "personal_output": personal_output,
            "global_output": global_output
        }

@st.composite
def mock_messages(draw) -> list[Message]:
    n_messages = draw(st.integers(min_value = 1, max_value = 10))

    messages = []

    for i in range(n_messages):
        message = draw(mock_message("assistant" if i % 2 == 0 else "user"))
        messages.append(message)
    
    return messages

@st.composite
def mock_context_update(draw, agent_ids: list[str] | None = None, updates: bool | None = None, new_msg: bool | None = None, delete: bool | None = None, role: str | None = None) -> ContextUpdate:
    context_update = {}

    if not updates:
        updates = draw(st.booleans())
    
    if not new_msg:
        new_msg = draw(st.booleans())

    if not delete:
        delete = draw(st.booleans())
    
    keys_st = st.sampled_from(agent_ids) if agent_ids else st.text(min_size = 1)
    values_st = mock_message(role) if role else mock_message()
    dict_st = st.dictionaries(keys = keys_st, values = values_st, min_size = 1)
    
    if updates:
        context_update["updates"] = draw(dict_st)
    
    if new_msg:
        context_update["new_msg"] = draw(dict_st)
    
    if delete:
        context_update["delete"] = draw(st.dictionaries(keys = keys_st, values = st.integers(), min_size = 1))

    return context_update

@st.composite
def mock_agent_contexts(draw, agent_ids: list[str] | None = None):
    if not agent_ids:
        agent_ids = draw(st.lists(st.text(min_size = 1), min_size = 1, unique = True))

    return {agent_id: draw(mock_messages()) for agent_id in agent_ids}

@st.composite
def mock_agents_state(draw, agent_ids: list[str] | None = None, context_update: bool = False) -> AgentsState:
    
    if not agent_ids:
        agent_ids = draw(st.lists(st.text(min_size = 1), min_size = 1, unique = True))
    n_agents = len(agent_ids)
    workflow_mode = draw(st.sampled_from(["generator", "report"]))
    is_subagent = draw(st.booleans())

    system_prompts = draw(mock_dict(agent_ids))
    summaries = draw(mock_dict(agent_ids))
    turn = draw(st.integers(min_value = 0, max_value = n_agents - 1))

    if context_update:
        agent_contexts = draw(mock_context_update(agent_ids, updates = True, role = "user"))
    else:
        agent_contexts = draw(mock_agent_contexts(agent_ids))

    agents_state = make_initial_state(agent_ids, workflow_mode, "prompt", is_subagent)
    agents_state["system_prompts"] = system_prompts
    agents_state["summaries"] = summaries
    agents_state["agent_contexts"] = agent_contexts
    agents_state["turn"] = turn

    return agents_state
