from agents.state import AgentsState, get_agent_id, personal_output, global_output
from agents.prompts import make_agent_prompt
from agents.commands import Command, TraverseCommand, ExampleCommand, SubmitExperimentsCommand, CommandConstraints, execute_generator, SubagentCommand
from agents.format import format_messages
from ontology.updater import OntologyUpdater
from dataclasses import dataclass
from openrouter import OpenRouter
from openrouter.components import SystemMessage, UserMessage, AssistantMessage
from langgraph.types import Overwrite, interrupt
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

    def _check_experiments(self, state: AgentsState, new_state: AgentsState):
        if state["experiments_running"] and not self.redis_client.llen("experiments"):

            new_state["experiments_running"] = False

            global_output(state, new_state, "[NOTIFICATION] Experiments have finished running.\n\n", ignore_current = False)

    def _check_human_messages(self, state: AgentsState, new_state: AgentsState):
        if self.redis_client.llen("human_messages"):
            human_messages = []

            item = self.redis_client.rpop("human_messages")

            while item:
                human_messages.append(item.decode("utf-8"))
                item = self.redis_client.rpop("human_messages")

            for msg in human_messages:
                global_output(state, new_state, f"[HUMAN] {msg}\n\n", ignore_current = False)

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

        self._check_experiments(state, new_state)
        self._check_human_messages(state, new_state)
        
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
                if len(state["agent_order"]) > 1:
                    content = f"PERSONAL OUTPUT:\n\n{msg['personal_output']}\n\nGLOBAL OUTPUT:\n\n{msg['global_output']}\n\n"
                else:
                    content = f"{msg['personal_output']}\n\n"
                
                new_msg = UserMessage(content = content)
            
            context.append(new_msg)

        with open(f"../data/{agent_id}_context.txt", "w") as file:
            text = ""
            for ctx_msg in context:
                text += f"ROLE: {ctx_msg.ROLE.upper()}\n\n{ctx_msg.content}\n\n"
            
            file.write(text)
        
        model_output = query_llm(self.open_router, self.models[agent_id], context)
        print("MODEL OUTPUT:", model_output)

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
    models: dict[str, list[str]]
    n_delete: dict[str, list[int]]

    def _summary(self, state: AgentsState, n_delete: int) -> str:
        agent_id = get_agent_id(state)

        text = format_messages(state["agent_contexts"][agent_id][:n_delete])

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
        new_system_prompt = make_agent_prompt(state["agent_order"], agent_id, summary, state["subagent_task"])

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
    constraints: dict[str, CommandConstraints]
    redis_client: redis.Redis
    open_router: OpenRouter
    subagent_pool: list
        
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

            agent_id = get_agent_id(state)
            command = adapter.validate_python(full_command, context = self.constraints[agent_id])

            if isinstance(command, (TraverseCommand, ExampleCommand)):
                command.run(state, new_state, self.updater)
            elif isinstance(command, SubmitExperimentsCommand):
                command.run(state, new_state, self.redis_client)
            elif isinstance(command, SubagentCommand):
                command.run(state, new_state, self.subagent_pool, self.updater, self.open_router, self.redis_client)
            else:
                command.run(state, new_state)
        
        except Exception as error:
            print(error)
            personal_output(state, new_state, f"[ERROR] Error occured when executing command: {error}\n\n")

        return new_state

@dataclass
class ApprovalNode:

    def __call__(self, state: AgentsState) -> AgentsState:
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

        agent_id = state["proposal_agent"]

        with open("../data/proposal.json", "w") as file:
            file.write(state["proposal"])

        approved = interrupt(f"Proposal by {agent_id} written to data/proposal.json\n Approve (y/n)?")

        if approved:

            personal_output(state, new_state, "[APPROVAL] Proposal approved.\n\n")

            global_output(state, new_state, f"[PROPOSAL] {agent_id} has proposed a generation script. Voting is now in session.\n", ignore_current = False)
            global_output(state, new_state, f"{state['proposal']}\n\n")

        else:

            personal_output(state, new_state, "[APPROVAL] Proposal rejected.\n\n")
            
            new_state["proposal"] = None
            new_state["proposal_agent"] = None
            new_state["votes"] = Overwrite([])

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

    def _close_voting(self, state: AgentsState, new_state: AgentsState):

        n_agents = len(state["agent_order"])
        n_votes = len(state["votes"])
        
        msg = f"[VOTE] {n_votes}/{n_agents} agents have voted in favor of the proposal.\n"

        majority_threshold = n_agents // 2

        if n_votes > majority_threshold:

            if not state["subagent_task"]:
                msg += "[VOTE] Vote has passed. Executing experiment generation.\n\n"

                try:
                    proposal = json.loads(state["proposal"])
                    execute_generator(proposal["generator"], proposal["search_space"], self.redis_client)
                except Exception as error:
                    msg += "[ERROR] Error occurred when executing: " + str(error) + "\n\n"

                new_state["experiments_running"] = True
            
            else:
                msg += "[VOTE] Vote has passed. Report submitted.\n\n"
                new_state["report"] = state["proposal"]


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
