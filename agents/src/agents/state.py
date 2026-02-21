from typing import TypedDict, Annotated
from operator import add

class Message(TypedDict, total = False):
    role: str
    model_output: str
    personal_output: str
    global_output: str

class ContextUpdate(TypedDict, total = False):
    updates: dict[str, Message]
    new_msg: dict[str, str]
    delete: dict[str, int]

def update_context(old: dict[str, list[Message]], update: ContextUpdate) -> dict[str, list[Message]]:
    new = {key: [msg.copy() for msg in val] for key, val in old.items()}

    if "updates" in update:
        for agent_id, msg_update in update["updates"].items():

            for key in msg_update.keys():
                new[agent_id][-1][key] += msg_update[key]

    if "new_msg" in update:
        for agent_id, new_role in update["new_msg"].items():
            new_msg = {"role": new_role}

            if new_role == "assistant":
                new_msg["model_output"] = ""
            elif new_role == "user":
                new_msg["personal_output"] = ""
                new_msg["global_output"] = ""

            new[agent_id].append(new_msg)

    if "delete" in update:
        for agent_id, n_delete in update["delete"].items():
            new[agent_id] = new[agent_id][n_delete:]
    
    return new

def update_dict(old: dict[str, str], update: dict[str, str]) -> dict[str, str]:
    new = old.copy()
    new.update(update)
    return new

class AgentsState(TypedDict):
    system_prompts: Annotated[dict[str, str], update_dict]
    summaries: Annotated[dict[str, str], update_dict]
    plans: Annotated[dict[str, str], update_dict]
    agent_contexts: Annotated[dict[str, list[Message]], update_context]

    commands: list[str]
    params: list[dict]

    proposal: str | None
    proposal_agent: str | None
    votes: Annotated[list[str], add]
    experiments_running: bool

    agent_order: list[str]
    turn: int
    n_rounds: int
    plan_counters: Annotated[dict[str, int], update_dict]

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

def remove_tags(prompt: str, tag: str, remove_inside: bool = False) -> str:
    if remove_inside:
        start_idx = prompt.index(f"<{tag}>")
        end_idx = prompt.index(f"</{tag}>", start_idx)
        end_idx += len(f"</{tag}>")

        return prompt[:start_idx] + prompt[end_idx:]
    
    prompt = prompt.replace(f"<{tag}>", "")
    return prompt.replace(f"</{tag}>", "")

def make_agent_prompt(agent_ids: list[str], curr_agent_id: str, plan: str, summary: str) -> str:
    with open("src/agents/prompt.md") as file:
        prompt = file.read()

    prompt = remove_tags(prompt, "PLANNER_PROFILE", remove_inside = True)
    prompt = remove_tags(prompt, "PLANNER_SPECIFIC", remove_inside = True)
    prompt = remove_tags(prompt, "AGENT_PROFILE")
    prompt = remove_tags(prompt, "AGENT_SPECIFIC")
    
    other_agents_str = ",".join([agent_id for agent_id in agent_ids if agent_id != curr_agent_id])
    
    prompt = prompt.replace("[AGENT_ID]", curr_agent_id)
    prompt = prompt.replace("[OTHER_AGENTS]", other_agents_str)
    prompt = prompt.replace("[SUMMARY]", summary)
    prompt = prompt.replace("[PLAN]", plan)

    return prompt

def make_planner_prompt(agent_id: str, interaction: str, plan: str, summary: str) -> str:
    with open("src/agents/prompt.md") as file:
        prompt = file.read()

    prompt = remove_tags(prompt, "AGENT_PROFILE", remove_inside = True)
    prompt = remove_tags(prompt, "AGENT_SPECIFIC", remove_inside = True)
    prompt = remove_tags(prompt, "PLANNER_PROFILE")
    prompt = remove_tags(prompt, "PLANNER_SPECIFIC")

    prompt = prompt.replace("[AGENT_ID]", agent_id)
    prompt = prompt.replace("[SUMMARY]", summary)
    prompt = prompt.replace("[INTERACTION]", interaction)
    prompt = prompt.replace("[PLAN]", plan)

    return prompt

def make_initial_state(agent_order: list[str]) -> AgentsState:
    system_prompts = {}

    for agent_id in agent_order:
        system_prompts[agent_id] = make_agent_prompt(agent_order, agent_id, "", "")

    return {
        "system_prompts": system_prompts,
        "summaries": {
            agent_id: "" for agent_id in agent_order
        },
        "plans": {
            agent_id: "" for agent_id in agent_order
        },
        "agent_contexts": {
            agent_id: [
                {
                    "role": "user",
                    "personal_output": "[SYSTEM] You recommended first command is to send a greeting to your fellow agents.",
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
        
        "agent_order": agent_order,
        "turn": 0,
        "n_rounds": 0,
        "plan_counters": {agent_id: 0 for agent_id in agent_order}
    }