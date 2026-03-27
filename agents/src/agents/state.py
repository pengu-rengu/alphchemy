from typing import TypedDict, Annotated, Literal
from operator import add
from agents.prompts import make_agent_prompt

class Message(TypedDict, total = False):
    role: Literal["assistant", "user"]
    model_output: str
    personal_output: str
    global_output: str

class ContextUpdate(TypedDict, total = False):
    updates: dict[str, Message]
    new_msg: dict[str, str]
    delete: dict[str, int]

def append_update(new: dict[str, list[Message]], updates: dict[str, Message]):
    for agent_id, msg_update in updates.items():
        for key in msg_update.keys():
            new[agent_id][-1][key] += msg_update[key]

def new_msg_update(new: dict[str, list[Message]], new_msg: dict[str, str]):
    for agent_id, new_role in new_msg.items():
        new_msg = {"role": new_role}

        if new_role == "assistant":
            new_msg["model_output"] = ""
        elif new_role == "user":
            new_msg["personal_output"] = ""
            new_msg["global_output"] = ""

        new[agent_id].append(new_msg)

def delete_update(new: dict[str, list[Message]], delete: dict[str, int]):
    for agent_id, n_delete in delete.items():
        new[agent_id] = new[agent_id][n_delete:]

def update_context(old: dict[str, list[Message]], update: ContextUpdate) -> dict[str, list[Message]]:
    new = {key: [msg.copy() for msg in val] for key, val in old.items()}

    if "updates" in update:
        append_update(new, update["updates"])

    if "new_msg" in update:
        new_msg_update(new, update["new_msg"])

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

    proposal: str | None
    proposal_agent: str | None
    votes: Annotated[list[str], add]
    experiments_running: bool
    report: str | None
    done: bool

    agent_order: list[str]
    turn: int
    n_rounds: int

    subagent_task: str | None

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


def make_initial_state(agent_order: list[str], subagent_task: str | None = None) -> AgentsState:
    system_prompts = {}

    is_multi = len(agent_order) > 1

    for agent_id in agent_order:
        system_prompts[agent_id] = make_agent_prompt(agent_order, agent_id, "", subagent_task)

    return {
        "system_prompts": system_prompts,
        "summaries": {
            agent_id: "" for agent_id in agent_order
        },
        "agent_contexts": {
            agent_id: [
                {
                    "role": "user",
                    "personal_output": "[SYSTEM] Your recommended first action is to send a greeting to your fellow agents." if is_multi else "[SYSTEM] Your recommended first action is to explore the Ontology.",
                    "global_output": ""
                }
            ] for agent_id in agent_order
        },

        "commands": [],
        "params": [],

        "proposal": None,
        "proposal_agent": None,
        "votes": [],
        "experiments_running": False,
        "report": None,
        "done": False,
        
        "agent_order": agent_order,
        "turn": 0,
        "n_rounds": 0,

        "subagent_task": subagent_task
    }
