
from typing import TypedDict, Annotated, Literal
from operator import add
from langgraph.graph import StateGraph, START, END
from langgraph.types import Overwrite
from langgraph.checkpoint.memory import MemorySaver
from prompts import format_hypotheses, format_context, make_system_prompt
from ontology import Ontology, parse_ontology
from openai import OpenAI
import redis
import json
import random
import dotenv

class OutputsUpdate(TypedDict):
    updates: dict[str, str]
    create_new: dict[str, bool]

def update_outputs(old: dict[str, list[str]], update: OutputsUpdate) -> dict[str, list[str]]:
    new = {k: v[:] for k, v in old.items()}

    for agent_id, contents in update["updates"].items():
        
        outputs = new[agent_id]

        outputs[-1] += contents
        if update["create_new"][agent_id]:
            outputs.append("")
    
    return new

class AgentsState(TypedDict):

    system_prompts: dict[str, str]
    model_outputs: Annotated[dict[str, list[str]], update_outputs]
    personal_outputs: Annotated[dict[str, list[str]], update_outputs]
    global_outputs: Annotated[dict[str, list[str]], update_outputs]

    commands: list[str]
    params: list[dict]

    proposal: str | None
    proposal_agent: str | None
    votes: Annotated[list[str], add]

    agent_order: list[str]
    turn: int
    n_rounds: int

def get_agent_id(state: AgentsState) -> str:
    turn = state["turn"]
    return state["agent_order"][turn]

def init_outputs(agent_ids: list[str], list_init = False):
    return {agent_id: ([""] if list_init else "") for agent_id in agent_ids}

def personal_output(state: AgentsState, new_state: AgentsState, contents: str, agent_id: str | None = None):
    if not agent_id:
        agent_id = get_agent_id(state)
    
    new_state["personal_outputs"]["updates"][agent_id] += contents

def global_output(state: AgentsState, new_state: AgentsState, contents: str, ignore_current: bool = True):
    current_agent_id = get_agent_id(state)

    for agent_id in state["agent_order"]:
        if ignore_current and current_agent_id == agent_id:
            continue
        new_state["global_outputs"]["updates"][agent_id] += contents

class LLMNode:

    def __init__(self, openai_client: OpenAI):
        self.openai_client = openai_client
    
    def __call__(self, state: AgentsState) -> AgentsState:

        agent_id = get_agent_id(state)

        context = format_context(state["system_prompts"][agent_id], state["model_outputs"][agent_id], state["personal_outputs"][agent_id], state["global_outputs"][agent_id])

        print(context)

        with open(f"data/{agent_id}_context.json", "w") as file:
            json.dump(context, file, indent = 2)
        
        response = self.openai_client.responses.create(
            model = "gpt-5.2-pro",
            input = context,
            text = {
                "format": {
                    "type": "json_object"
                }
            }
        )
        model_output = response.output_text
        print(model_output)

        commands_json = json.loads(model_output)["commands"]
        commands = []
        params = []

        for command_json in commands_json:
            command = command_json.pop("command")
            commands.append(command)
            params.append(command_json)

        return {
            "commands": commands,
            "params": params,
            "model_outputs": {
                "updates": {
                    agent_id: model_output
                },
                "create_new": {
                    agent_id: True
                }
            }
        }

class CommandNode:
    def __init__(self, ontology: Ontology):
        self.ontology = ontology

    def _propose(self, state: AgentsState, new_state: AgentsState):
        
        if state["proposal"]:
            personal_output(state, new_state, "[ERROR] Cannot propose while voting is in session.\n\n")
            return

        params = state["params"][0]
        agent_id = get_agent_id(state)

        new_state["proposal"] = params["code"]
        new_state["proposal_agent"] = agent_id

        global_output(state, new_state, f"[PROPOSAL] {agent_id} has proposed a generation script. Voting is now in session.\n", ignore_current = False)
        global_output(state, new_state, f"{new_state['proposal']}\n\n")

    def _vote(self, state: AgentsState, new_state: AgentsState):
        agent_id = get_agent_id(state)

        if not state["proposal"]:
            personal_output(state, new_state, f"[ERROR] Voting is not in session.\n\n")
            return

        if agent_id in state["votes"]:
            personal_output(state, new_state, "[ERROR] You have already voted.\n\n")
            return

        global_output(state, new_state, f"[VOTE] {agent_id} has voted in favor of the proposal.", ignore_current = False)
        new_state["votes"] = [agent_id]
        
    def _message(self, state: AgentsState, new_state: AgentsState):
        params = state["params"][0]
        agent_id = get_agent_id(state)

        global_output(state, new_state, f"[{agent_id}] {params['contents']}\n\n")

    def _traverse(self, state: AgentsState, new_state: AgentsState):
        params = state["params"][0]
        hyp_id = params["hyp_id"]

        if hyp_id < 0:
            focal_hyp = random.choice(self.ontology.hypotheses)
        else:
            focal_hyp = next((h for h in self.ontology.hypotheses if h.id == hyp_id), None)

        if not focal_hyp:
            personal_output(state, new_state, f"[ERROR] Hypothesis {hyp_id} not found.\n\n")
        
        else:
            
            algorithm = params["algorithm"]

            traversal = self.ontology.traverse(focal_hyp, algorithm, params["max_count"])
            traversal_str = format_hypotheses(traversal, self.ontology.result_metric)

            personal_output(state, new_state, f"[TRAVERSAL]\n{traversal_str}")
    
    def __call__(self, state: AgentsState) -> AgentsState:

        command = state["commands"][0]
        agent_id = get_agent_id(state)

        new_state = {
            "personal_outputs": {
                "updates": {
                    agent_id: ""
                },
                "create_new": {
                    agent_id: False
                }
            },
            "global_outputs": {
                "updates": init_outputs(state["agent_order"]),
                "create_new": {aid: False for aid in state["agent_order"]}
            },
            "commands": state["commands"][1:],
            "params": state["params"][1:]
        }

        if command == "propose":
            self._propose(state, new_state)
        elif command == "vote":
            self._vote(state, new_state)
        elif command == "message":
            self._message(state, new_state)
        elif command == "traverse":
            self._traverse(state, new_state)
        elif command == "examples":
            personal_output(state, new_state, "[ERROR] Command 'examples' is not yet implemented.\n\n", None)
        else:
            personal_output(state, new_state, f"[ERROR] Unknown command: {command}.\n\n", None)

        return new_state

class EndTurnNode:

    def _update_turn(self, state: AgentsState, new_state: AgentsState):
        n_agents = len(state["agent_order"])

        new_state["turn"] = state["turn"] + 1

        if new_state["turn"] >= n_agents:
            new_state["n_rounds"] = state["n_rounds"] + 1
            new_state["turn"] = 0

    def _check_votes(self, state: AgentsState, new_state: AgentsState) -> bool:
        next_turn = new_state["turn"]
        is_last_agent = state["agent_order"][next_turn] == state["proposal_agent"]

        return state["proposal"] and is_last_agent

    def _close_voting(self, state: AgentsState, new_state: AgentsState):

        n_agents = len(state["agent_order"])
        n_votes = len(state["votes"])
        
        msg = f"[VOTE] {n_votes}/{n_agents} agents have voted in favor of the proposal\n"

        majority_threshold = n_agents // 2

        if n_votes > majority_threshold:
            msg += "[VOTE] Vote has passed. Executing generation script.\n\n"
        else:
            msg += "[VOTE] Vote has not passed.\n\n"
        
        global_output(state, new_state, msg, ignore_current = False)

        new_state["proposal"] = None
        new_state["proposal_agent"] = None
        new_state["votes"] = Overwrite([])

    def __call__(self, state: AgentsState):
        agent_ids = state["agent_order"]
        curr_agent_id = get_agent_id(state)

        new_state = {
            "personal_outputs": {
                "updates": {
                    curr_agent_id: ""
                },
                "create_new": {
                    curr_agent_id: True
                }
            },
            "global_outputs": {
                "updates": init_outputs(agent_ids),
                "create_new": {agent_id: agent_id == curr_agent_id for agent_id in agent_ids}
            }
        }
        
        self._update_turn(state, new_state)
        
        if self._check_votes(state, new_state):
            self._close_voting(state, new_state)

        return new_state

class AgentSystem:

    def __init__(self, ontology: Ontology, openai_client: OpenAI, redis_client: redis.Redis):
        self.ontology = ontology
        self.redis_client = redis_client

        llm_node = LLMNode(openai_client)
        command_node = CommandNode(ontology)
        end_turn_node = EndTurnNode()

        graph = StateGraph(AgentsState)
        graph.add_node("llm", llm_node)
        graph.add_node("command", command_node)
        graph.add_node("end_turn", end_turn_node)

        graph.add_edge(START, "llm")
        graph.add_edge("llm", "command")
        graph.add_conditional_edges("command", self.command_router)
        graph.add_conditional_edges(
            "end_turn",
            self.terminate_router,
            {
                "llm": "llm",
                END: END
            }
        )

        self.checkpointer = MemorySaver()
        self.graph = graph.compile(checkpointer=self.checkpointer)
    
    def command_router(self, state: AgentsState) -> Literal["command", "end_turn"]:
        
        if not state["commands"]:
            return "end_turn"
        
        return "command"
    
    def terminate_router(self, state: AgentsState) -> Literal["llm", "END"]:
        if state["n_rounds"] >= 5:
            return END
        
        return "llm"
    
if __name__ == "__main__":
    dotenv.load_dotenv(".env", override = True)

    with open("data/ontology.json", "r") as file:
        ontology_json = json.load(file)
    
    ontology = parse_ontology(ontology_json)

    openai_client = OpenAI()
    redis_client = redis.Redis()
    agents = AgentSystem(ontology, openai_client, redis_client)

    system_prompts = {}

    for agent_id in ["Agent 1", "Agent 2"]:
        system_prompts[agent_id] = make_system_prompt(["Agent 2"] if agent_id == "Agent 1" else ["Agent 1"], 900)
    
    initial_state = {
        "agent_order": ["Agent 1", "Agent 2"],
        "turn": 0,
        "system_prompts": system_prompts,
        "model_outputs": Overwrite({
            "Agent 1": [""],
            "Agent 2": [""]
        }),
        "personal_outputs": Overwrite({
            "Agent 1": [""],
            "Agent 2": [""]
        }),
        "global_outputs": Overwrite({
            "Agent 1": [""],
            "Agent 2": [""]
        }),
        "commands": [],
        "params": [],
        "proposal": None,
        "proposal_agent": None,
        "votes": [],
        "n_rounds": 0
    }
    config = {"configurable": {"thread_id": "1"}}
    agents.graph.invoke(initial_state, config=config)
    