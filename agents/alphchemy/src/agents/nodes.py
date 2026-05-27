from __future__ import annotations

from agents.state import AgentsState, get_agent_id, personal_output, global_output
from agents.prompts import make_system_prompt
from agents.commands import AnalyzeDataCommand, Command, SubagentCommand
from agents.format import format_messages, format_output_items
from dataclasses import dataclass
from openrouter import OpenRouter
from openrouter.components import ChatSystemMessage, ChatUserMessage, ChatAssistantMessage
from pydantic import TypeAdapter
from typing import TYPE_CHECKING
import json

if TYPE_CHECKING:
    from supabase import Client

def query_llm(open_router: OpenRouter, model: str, fallback_model: str, context: list[ChatSystemMessage | ChatUserMessage | ChatAssistantMessage], json_mode = True) -> str:

    response = open_router.chat.send(
        messages = context,
        models = [model, fallback_model],
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

    def __call__(self, state: AgentsState) -> AgentsState:
        current_agent_id = get_agent_id(state)

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
    models: dict[str, tuple[str, str]]
    additional_instructions: dict[str, str]

    def __call__(self, state: AgentsState) -> AgentsState:

        agent_id = get_agent_id(state)
        prompt = make_system_prompt(state, self.additional_instructions[agent_id])
        context = [ChatSystemMessage(role = "system", content = prompt)]

        for msg in state["agent_contexts"][agent_id][:-1]:
            
            if msg["role"] == "assistant":
                new_msg = ChatAssistantMessage(
                    role = "assistant",
                    content = msg["model_output"]
                )
            elif msg["role"] == "user":
                personal = format_output_items(msg["personal_output"])
                if len(state["agent_order"]) > 1:
                    global_part = format_output_items(msg["global_output"])
                    content = f"PERSONAL OUTPUT:\n\n{personal}\n\nGLOBAL OUTPUT:\n\n{global_part}\n\n"
                else:
                    content = f"{personal}\n\n"
                
                new_msg = ChatUserMessage(
                    role = "user",
                    content = content
                )
            
            context.append(new_msg)
        
        model, fallback_model = self.models[agent_id]
        model_output = query_llm(self.open_router, model, fallback_model, context)
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
    models: dict[str, tuple[str, str]]
    n_delete: dict[str, int]

    def make_summary(self, state: AgentsState, n_delete: int) -> str:
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
        
        message = ChatSystemMessage(
            role = "system",
            content = prompt
        )

        model, fallback_model = self.models[agent_id]
        return query_llm(self.open_router, model, fallback_model, [message], json_mode = False)


    def __call__(self, state: AgentsState) -> AgentsState:

        agent_id = get_agent_id(state)
        n_delete = self.n_delete[agent_id]
        
        summary = self.make_summary(state, n_delete)

        return {
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
    supabase: Client
        
    def __call__(self, state: AgentsState) -> AgentsState:
        new_state = {
            "agent_contexts": {
                "updates": {
                    aid: {
                        "personal_output": [],
                        "global_output": []
                    } for aid in state["agent_order"]
                }
            },
            "commands": state["commands"][1:],
            "params": state["params"][1:]
        }

        commands = state["commands"]

        if not commands:
            personal_output(state, new_state, {"tag": "ERROR", "content": "No commands to be executed."})
            return new_state

        command_name = commands[0]
        command_params = state["params"][0]
        full_command = command_params.copy()
        full_command["command"] = command_name

        try:
            adapter = TypeAdapter(Command)
            command = adapter.validate_python(full_command)

            if isinstance(command, SubagentCommand):
                command.run(state, new_state, self.subagent_pool, self.open_router, self.supabase)
            elif isinstance(command, AnalyzeDataCommand):
                command.run(state, new_state, self.supabase)
            else:
                command.run(state, new_state)
        
        except Exception as error:
            print(error)
            personal_output(state, new_state, {"tag": "ERROR", "content": f"Error occured when executing command: {error}"})

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

        majority_threshold = n_agents // 2

        if n_votes > majority_threshold:
            new_state["proposal_state"] = {
                "state": "submission",
                "type": proposal_state["type"],
                "submission": proposal_state["proposal"].copy()
            }
            outcome = "Vote has passed."

        else:
            new_state["proposal_state"] = {
                "state": "idle"
            }
            outcome = "Vote has not passed."

        content = f"{n_votes}/{n_agents} agents have voted in favor of the proposal. {outcome}"
        global_output(state, new_state, {"tag": "VOTE", "content": content}, ignore_current = False)

    def __call__(self, state: AgentsState):
        new_state = {
            "agent_contexts": {
                "updates": {
                    agent_id: {
                        "personal_output": [],
                        "global_output": []
                    } for agent_id in state["agent_order"]
                }
            }
        }
        
        self._update_turn(state, new_state)
        
        if self._check_votes(state, new_state):
            self._close_voting(state, new_state)

        return new_state
