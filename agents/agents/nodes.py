from agents.state import AgentsState, get_agent_id, make_agent_prompt, make_planner_prompt, personal_output, global_output, interaction_text
from agents.commands import Command, TraverseCommand, ExampleCommand
from ontology.updater import OntologyUpdater
from dataclasses import dataclass
from openrouter import OpenRouter
from openrouter.components import SystemMessage, UserMessage, AssistantMessage
from langgraph.types import Overwrite
from pydantic import TypeAdapter
import json
import redis

def query_llm(open_router: OpenRouter, models: list[str], context: list[SystemMessage | UserMessage | AssistantMessage], json_mode = True) -> str:

    response = open_router.chat.send(
        messages = context,
        models = models,
        response_format = {
            "type": "json_object"
        } if json_mode else {
            "type": "text"
        },
        timeout_ms = 60 * 1000
    )
    print("MODEL:", response.model)

    return response.choices[0].message.content

@dataclass
class StartTurnNode:

    redis_client: redis.Redis
    updater: OntologyUpdater

    def __call__(self, state: AgentsState) -> AgentsState:
        agent_id = get_agent_id(state)

        new_state = {
            "agent_contexts": {
                "updates": {
                    aid: {
                        "personal_output": "",
                        "global_output": ""
                    } for aid in state["agent_order"]
                },
                "new_msg": {
                    agent_id: "assistant"
                }
            }
        }

        if self.updater.check_rebuilt():
            global_output(state, new_state, "[NOTIFICATION] Ontology has been rebuilt.\n\n", ignore_current = False)

        if state["experiments_running"] and not self.redis_client.llen("experiments"):

            new_state["experiments_running"] = False

            global_output(state, new_state, "[NOTIFICATION] Experiments have finished running.\n\n", ignore_current = False)

        return new_state

@dataclass
class LLMNode:
    open_router: OpenRouter
    models: dict[str, list[str]]
    
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
        
        model_output = query_llm(self.open_router, self.models[agent_id], context)
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
class PlanNode:
    open_router: OpenRouter
    models: dict[str, list[str]]
    plan_freq: dict[str, int]

    def __call__(self, state: AgentsState) -> AgentsState:
        agent_id = get_agent_id(state)
        plan_counter = state["plan_counters"][agent_id]

        if plan_counter < self.plan_freq[agent_id]:
            return {
                "plan_counters": {
                    agent_id: plan_counter + 1
                }
            }

        summary = state["summaries"][agent_id]

        interaction = interaction_text(state["agent_contexts"][agent_id])
        prompt = make_planner_prompt(agent_id, interaction, state["plans"][agent_id], summary)

        message = SystemMessage(content = prompt)

        new_plan = query_llm(self.open_router, self.models[agent_id], [message], json_mode = False)

        print(prompt)
        print("NEW PLAN:", new_plan)

        if "PLAN_INCOMPLETE" in new_plan:
            return {}
        
        new_system_prompt = make_agent_prompt(state["agent_order"], agent_id, new_plan, summary)

        return {
            "system_prompts": {
                agent_id: new_system_prompt
            },
            "plans": {
                agent_id: new_plan
            },
            "plan_counters": {
                agent_id: 0
            }
        }

@dataclass
class SummarizeNode:
    open_router: OpenRouter
    models: dict[str, list[str]]
    n_delete: dict[str, list[int]]

    def _summary(self, state: AgentsState, n_delete: int) -> str:
        agent_id = get_agent_id(state)

        text = interaction_text(state["agent_contexts"][agent_id][:n_delete])

        prompt = f"""** Current summary: **

{state['summaries'][agent_id]}

** Guidelines **
- Focus on key information and important events.
- Outline all reasoning for decisions made.
- Inlcude any unresolved questions or tasks.

** Your Directive **

Along with the current summary, summarize following interaction between multiple AI agents:

{text}"""
        
        message = SystemMessage(content = prompt)

        return query_llm(self.open_router, self.models[agent_id], [message], json_mode = False)


    def __call__(self, state: AgentsState) -> AgentsState:

        agent_id = get_agent_id(state)
        n_delete = self.n_delete[agent_id]
        
        summary = self._summary(state, n_delete)
        new_system_prompt = make_agent_prompt(state["agent_order"], agent_id, state["plans"][agent_id], summary)

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
    updater: OntologyUpdater
        
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

        command_name = commands[0]
        command_params = state["params"][0]
        full_command = command_params.copy()
        full_command["command"] = command_name

        try:
            adapter = TypeAdapter(Command)
            command = adapter.validate_python(full_command)

            if isinstance(command, (TraverseCommand, ExampleCommand)):
                command.run(state, new_state, self.updater)
            else:
                command.run(state, new_state)
        
        except Exception as error:
            print(error)
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
                msg += "[ERROR] Error occured when executing script: " + str(error) + ".\n\n"

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