from agents.state import AgentsState, get_agent_id, make_system_prompt, personal_output, global_output
from agents.prompts import format_hypotheses
from ontology.ontology import Ontology
from dataclasses import dataclass
from openrouter import OpenRouter
from openrouter.components import SystemMessage, UserMessage, AssistantMessage
from langgraph.types import Overwrite
import json
import redis
import random

def query_llm(open_router: OpenRouter, models: list[str], context: list[SystemMessage | UserMessage | AssistantMessage]) -> str:

    response = open_router.chat.send(
        messages = context,
        models = models,
        response_format = {
            "type": "json_object"
        }
    )
    print("MODEL:", response.model)

    return response.choices[0].message.content

@dataclass
class StartTurnNode:

    redis_client: redis.Redis

    def __call__(self, state: AgentsState) -> AgentsState:
        agent_id = get_agent_id(state)

        new_state = {
            "agent_contexts": {
                "new_msg": {
                    agent_id: "assistant"
                }
            }
        }

        if state["experiments_running"] and not self.redis_client.llen("experiments"):

            new_state["experiments_running"] = False

            global_output(state, new_state, "[NOTIFICATION] Experiments have finished running.\n\n", ignore_current = False)

        return new_state

@dataclass
class LLMNode:
    open_router: OpenRouter
    models: list[str]
    
    def __call__(self, state: AgentsState) -> AgentsState:

        agent_id = get_agent_id(state)
        context = [SystemMessage(content = state["system_prompts"][agent_id])]

        for msg in state["agent_contexts"][agent_id][:-1]:
            
            if msg["role"] == "assistant":
                new_msg = AssistantMessage(content = msg["model_output"])
            elif msg["role"] == "user":
                new_msg = UserMessage(content = f"PERSONAL OUTPUT:\n\n{msg['personal_output']}\n\nGLOBAL OUTPUT:\n\n{msg['global_output']}\n\n")
            
            context.append(new_msg)

        with open(f"data/{agent_id}_context.txt", "w") as file:
            text = ""
            for ctx_msg in context:
                text += f"ROLE: {ctx_msg.ROLE.upper()}\n\n{ctx_msg.content}\n\n"
            
            file.write(text)
        
        model_output = query_llm(self.open_router, self.models, context)
        print("MODEL OUPTUT:", model_output)

        try:
            output_json = json.loads(model_output)
        except json.JSONDecodeError:
            output_json = {}

        commands = []
        params = []

        if "commands" in output_json:

            commands_json = output_json["commands"]

            for command_json in commands_json:
                if "command" not in command_json:
                    continue
                
                command = command_json.pop("command")
                commands.append(command)
                params.append(command_json)

        return {
            "commands": commands,
            "params": params,
            "agent_contexts": {
                "updates": {
                    agent_id: {"model_output": model_output}
                },
                "new_msg": {
                    agent_id: "user"
                }
            }
        }

@dataclass
class SummarizeNode:
    open_router: OpenRouter
    delete_frac: float
    models: list[str]

    def _summary(self, state: AgentsState, n_delete: int) -> str:
        agent_id = get_agent_id(state)

        text = ""
        for message in state["agent_contexts"][agent_id][:n_delete + 1]:
            role = message["role"]

            text += f"** ROLE: {role.upper()} **\n\n"

            if role == "assistant":
                text += message["model_output"]
            elif role == "user":
                text += f"PERSONAL OUTPUT:\n\n{message['personal_output']}\n\nGLOBAL OUTPUT:\n\n{message['global_output']}"
            
            text += "\n\n"

        print(text)
        
        prompt = SystemMessage(content = f"** Current summary: **\n\n{state['summaries'][agent_id]}\n\n** Your Directive **\n\nAlong witht the current summary, summarize following interaction between multiple AI agents:\n\n{text}")

        return query_llm(self.open_router, self.models, [prompt])


    def __call__(self, state: AgentsState) -> AgentsState:

        agent_id = get_agent_id(state)

        n_messages = len(state["agent_contexts"][agent_id])
        n_delete = self.delete_frac * n_messages
        n_delete = int(n_delete)
        
        summary = self._summary(state, n_delete)
        new_system_prompt = make_system_prompt(state["agent_order"], agent_id, summary)

        return {
            "system_prompts": {
                agent_id: new_system_prompt
            },
            "agent_contexts": {
                "delete": {
                    agent_id: n_delete
                }
            },
            "summaries": {
                agent_id: summary
            }
        }

@dataclass
class CommandNode:
    ontology: Ontology

    def _propose(self, state: AgentsState, new_state: AgentsState):
        
        if state["experiments_running"]:
            personal_output(state, new_state, "[ERROR] Cannot propose while experiments are already running.\n\n")
            return

        if state["proposal"]:
            personal_output(state, new_state, "[ERROR] Cannot propose while voting is in session.\n\n")
            return

        params = state["params"][0]
        agent_id = get_agent_id(state)

        new_state["proposal"] = params["code"]
        new_state["proposal_agent"] = agent_id
        new_state["votes"] = [agent_id]

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
        max_count = params["max_count"]

        if max_count > 10:
            personal_output("[ERROR] Cannot traverse more than 10 hypotheses.\n\n")
            return

        if hyp_id < 0:
            focal_hyp = random.choice(self.ontology.hypotheses)
        else:
            focal_hyp = next((h for h in self.ontology.hypotheses if h.id == hyp_id), None)

        if not focal_hyp:
            personal_output(state, new_state, f"[ERROR] Hypothesis {hyp_id} not found.\n\n")
            return
            
        algorithm = params["algorithm"]

        traversal = self.ontology.traverse(focal_hyp, algorithm, max_count)
        traversal_str = format_hypotheses(traversal, self.ontology.result_metric)

        personal_output(state, new_state, f"[TRAVERSAL]\n{traversal_str}")
    
    def _example(self, state: AgentsState, new_state: AgentsState):
        params = state["params"][0]
        hyp_id = params["hyp_id"]

        hyp = next((h for h in self.ontology.hypotheses if h.id == hyp_id), None)

        if not hyp:
            personal_output(state, new_state, f"[ERROR] Hypothesis {hyp_id} not found.\n\n")
            return
        
        experiment_id = random.choice(hyp.concept.ids)

        example = ""

        with open("data/experiments.jsonl", "r") as file:
            for id, line in enumerate(file):
                if id == experiment_id:
                    example += f"{line}\n\n"
        
        personal_output(state, new_state, f"[EXAMPLE]\n\n{example}\n\n")
    
    def __call__(self, state: AgentsState) -> AgentsState:
        new_state = {
            "agent_contexts": {
                "updates": {
                    aid: {
                        "personal_output": "",
                        "global_output": ""
                    } for aid in state["agent_order"]
                }
            },
            "commands": state["commands"][1:],
            "params": state["params"][1:]
        }

        commands = state["commands"]

        if not commands:
            personal_output(state, new_state, "[ERROR] No commands to be executed.\n\n")
            return new_state

        command = commands[0]

        try:
            if command == "propose":
                self._propose(state, new_state)
            elif command == "vote":
                self._vote(state, new_state)
            elif command == "message":
                self._message(state, new_state)
            elif command == "traverse":
                self._traverse(state, new_state)
            elif command == "example":
                self._example(state, new_state)
            else:
                personal_output(state, new_state, f"[ERROR] Unknown command: {command}.\n\n")
        
        except Exception as error:
            personal_output(state, new_state, f"[ERROR] Error occured when executing command: {error}\n\n")

        return new_state

@dataclass
class EndTurnNode:

    redis_client: redis.Redis

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

    def _execute_script(self, script: str):
        start_marker = "```python"
        start_idx = script.index(start_marker) + len(start_marker)
        end_idx = script.index("```", start_idx)
        script = script[start_idx:end_idx]

        funcs = {}

        exec(script, {}, funcs)

        experiments = funcs["generate_experiments"]()

        for experiment in experiments:
            experiment_data = json.dumps(experiment)
            self.redis_client.lpush("experiments", experiment_data)
        

    def _close_voting(self, state: AgentsState, new_state: AgentsState):

        n_agents = len(state["agent_order"])
        n_votes = len(state["votes"])
        
        msg = f"[VOTE] {n_votes}/{n_agents} agents have voted in favor of the proposal.\n"

        majority_threshold = n_agents // 2

        if n_votes > majority_threshold:
            msg += "[VOTE] Vote has passed. Executing experiment generation script.\n\n"
            try:
                self._execute_script(state["proposal"])
            except Exception as error:
                msg += "[ERROR] Error occured when executing script: " + str(error) + "\n\n"

            new_state["experiments_running"] = True
        else:
            msg += "[VOTE] Vote has not passed.\n\n"
        
        global_output(state, new_state, msg, ignore_current = False)

        new_state["proposal"] = None
        new_state["proposal_agent"] = None
        new_state["votes"] = Overwrite([])

    def __call__(self, state: AgentsState):
        new_state = {
            "agent_contexts": {
                "updates": {
                    aid: {
                        "personal_output": "",
                        "global_output": ""
                    } for aid in state["agent_order"]
                }
            }
        }
        
        self._update_turn(state, new_state)
        
        if self._check_votes(state, new_state):
            self._close_voting(state, new_state)

        return new_state