from typing import TypedDict, Annotated, Literal
from agents.prompts import make_agent_prompt

class Message(TypedDict, total = False):
    role: Literal["assistant", "user"]
    model_output: str
    personal_output: str
    global_output: str

class ContextUpdate(TypedDict, total = False):
    updates: dict[str, Message]
    new_msg: dict[str, str]
    append_msgs: dict[str, list[Message]]
    delete: dict[str, int]

class Idle(TypedDict):
    state: Literal["idle"]

class Proposal(TypedDict):
    state: Literal["proposal"]
    type: Literal["generator", "report"]
    proposal: dict
    agent_id: str
    votes: list[str]

class Submission(TypedDict):
    state: Literal["submission"]
    type: Literal["generator", "report"]
    submission: dict

class Rejection(TypedDict):
    state: Literal["rejection"]
    reason: str

def append_update(new: dict[str, list[Message]], updates: dict[str, Message]) -> None:
    for agent_id, msg_update in updates.items():
        for key in msg_update.keys():
            new[agent_id][-1][key] += msg_update[key]

def new_msg_update(new: dict[str, list[Message]], new_msg: dict[str, str]) -> None:
    for agent_id, new_role in new_msg.items():
        msg = {"role": new_role}

        if new_role == "assistant":
            msg["model_output"] = ""
        elif new_role == "user":
            msg["personal_output"] = ""
            msg["global_output"] = ""

        new[agent_id].append(msg)

def append_msgs_update(new: dict[str, list[Message]], append_msgs: dict[str, list[Message]]) -> None:
    for agent_id, messages in append_msgs.items():
        for message in messages:
            new[agent_id].append(message.copy())

def delete_update(new: dict[str, list[Message]], delete: dict[str, int]) -> None:
    for agent_id, n_delete in delete.items():
        new[agent_id] = new[agent_id][n_delete:]

def update_context(old: dict[str, list[Message]], update: ContextUpdate) -> dict[str, list[Message]]:
    new = {key: [msg.copy() for msg in val] for key, val in old.items()}

    if "updates" in update:
        append_update(new, update["updates"])

    if "new_msg" in update:
        new_msg_update(new, update["new_msg"])

    if "append_msgs" in update:
        append_msgs_update(new, update["append_msgs"])

    if "delete" in update:
        delete_update(new, update["delete"])
    
    return new

def update_dict(old: dict[str, str], update: dict[str, str]) -> dict[str, str]:
    new = old.copy()
    new.update(update)
    return new

class AgentsState(TypedDict):
    system_prompts: Annotated[dict[str, str], update_dict]
    summaries: Annotated[dict[str, str], update_dict]
    agent_contexts: Annotated[dict[str, list[Message]], update_context]

    commands: list[str]
    params: list[dict]

    proposal_state: Idle | Proposal | Submission | Rejection

    agent_order: list[str]
    turn: int

    is_subagent: bool

def get_agent_id(state: AgentsState) -> str:
    turn = state["turn"]
    return state["agent_order"][turn]

def personal_output(state: AgentsState, new_state: AgentsState, content: str, agent_id: str | None = None):
    if not agent_id:
        agent_id = get_agent_id(state)
    
    new_state["agent_contexts"]["updates"][agent_id]["personal_output"] += content

def global_output(state: AgentsState, new_state: AgentsState, content: str, ignore_current: bool = True):
    current_agent_id = get_agent_id(state)

    for agent_id in state["agent_order"]:
        if ignore_current and current_agent_id == agent_id:
            continue

        new_state["agent_contexts"]["updates"][agent_id]["global_output"] += content

def make_initial_state(agent_order: list[str], prompt: str, is_subagent: bool = False) -> AgentsState:
    system_prompts = {}

    for agent_id in agent_order:
        system_prompts[agent_id] = make_agent_prompt(agent_order, agent_id, prompt, "", is_subagent)

    return {
        "system_prompts": system_prompts,
        "summaries": {
            agent_id: "" for agent_id in agent_order
        },
        "agent_contexts": {
            agent_id: [
                {
                    "role": "user",
                    "personal_output": prompt,
                    "global_output": ""
                }
            ] for agent_id in agent_order
        },

        "commands": [],
        "params": [],

        "proposal_state": {
            "state": "idle"
        },

        "agent_order": agent_order,
        "turn": 0,

        "is_subagent": is_subagent
    }
