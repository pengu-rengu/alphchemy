from agents.state import AgentsState, get_agent_id, personal_output, global_output
from agents.prompts import make_agent_prompt
from agents.commands import Command, SubagentCommand
from agents.data_paths import agent_context_path, ensure_parent_dir
from agents.format import format_messages
from dataclasses import dataclass
from openrouter import OpenRouter
from openrouter.components import SystemMessage, UserMessage, AssistantMessage
from pydantic import TypeAdapter
import json

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

    def rejection_message(self, reason: str) -> str:
        return f"[HUMAN REJECTION]\nReason: {reason}\n\nRevise the generator submission and resubmit."

    def rejection_updates(self, state: AgentsState, current_agent_id: str) -> dict[str, list[dict[str, str]]]:
        proposal_state = state["proposal_state"]
        reason = proposal_state["reason"]
        content = self.rejection_message(reason)
        append_msgs = {}

        for agent_id in state["agent_order"]:
            append_msgs[agent_id] = [
                {
                    "role": "user",
                    "personal_output": content,
                    "global_output": ""
                }
            ]

        append_msgs[current_agent_id].append(
            {
                "role": "assistant",
                "model_output": ""
            }
        )
        return append_msgs

    def __call__(self, state: AgentsState) -> AgentsState:
        current_agent_id = get_agent_id(state)
        proposal_state = state["proposal_state"]

        if proposal_state["state"] == "rejection":
            return {
                "proposal_state": {
                    "state": "idle"
                },
                "agent_contexts": {
                    "append_msgs": self.rejection_updates(state, current_agent_id)
                }
            }

        new_state = {
            "agent_contexts": {
                "new_msg": {
                    current_agent_id: "assistant"
                }
            }
        }
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

        path = agent_context_path(agent_id)
        ensure_parent_dir(path)

        with open(path, "w") as file:
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
    n_delete: dict[str, int]
    prompt: str

    def _summary(self, state: AgentsState, n_delete: int) -> str:
        agent_id = get_agent_id(state)

        text = format_messages(state["agent_contexts"][agent_id][:n_delete])

        prompt = f"""** Current summary: **

{state['summaries'][agent_id]}

** Guidelines **
- Focus on key information and important events.
- Outline all reasoning for decisions made.
- Include any unresolved questions or tasks.

** Your Directive **

Along with the current summary, summarize following interaction between multiple AI agents:

{text}"""
        
        message = SystemMessage(content = prompt)

        return query_llm(self.open_router, self.models[agent_id], [message], json_mode = False)


    def __call__(self, state: AgentsState) -> AgentsState:

        agent_id = get_agent_id(state)
        n_delete = self.n_delete[agent_id]
        
        summary = self._summary(state, n_delete)
        new_system_prompt = make_agent_prompt(
            state["agent_order"],
            agent_id,
            self.prompt,
            summary,
            state["is_subagent"]
        )

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
            command = adapter.validate_python(full_command)

            if isinstance(command, SubagentCommand):
                command.run(state, new_state, self.subagent_pool, self.open_router)
            else:
                command.run(state, new_state)
        
        except Exception as error:
            print(error)
            personal_output(state, new_state, f"[ERROR] Error occured when executing command: {error}\n\n")

        return new_state

@dataclass
class EndTurnNode:

    def _update_turn(self, state: AgentsState, new_state: AgentsState):
        n_agents = len(state["agent_order"])

        new_state["turn"] = state["turn"] + 1

        if new_state["turn"] >= n_agents:
            new_state["turn"] = 0

    def _check_votes(self, state: AgentsState, new_state: AgentsState) -> bool:
        proposal_state = state["proposal_state"]

        if proposal_state["state"] != "proposal":
            return False

        next_turn = new_state["turn"]
        is_last_agent = state["agent_order"][next_turn] == proposal_state["agent_id"]

        return is_last_agent

    def _close_voting(self, state: AgentsState, new_state: AgentsState):
        proposal_state = state["proposal_state"]

        n_agents = len(state["agent_order"])
        n_votes = len(proposal_state["votes"])
        
        msg = f"[VOTE] {n_votes}/{n_agents} agents have voted in favor of the proposal.\n"

        majority_threshold = n_agents // 2

        if n_votes > majority_threshold:
            new_state["proposal_state"] = {
                "state": "submission",
                "type": proposal_state["type"],
                "submission": proposal_state["proposal"].copy()
            }

            msg += "[VOTE] Vote has passed.\n\n"

        else:
            new_state["proposal_state"] = {
                "state": "idle"
            }
            msg += "[VOTE] Vote has not passed.\n\n"
        
        global_output(state, new_state, msg, ignore_current = False)

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
