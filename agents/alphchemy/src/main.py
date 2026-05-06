from __future__ import annotations

import json
import os
from typing import Any

import dotenv
from agents.data_paths import state_path

STATE_PATH = state_path()


def submit_experiment(submission: dict[str, Any]) -> None:
    pass


def load_state() -> dict[str, Any] | None:
    try:
        with open(STATE_PATH, "r") as file:
            return json.load(file)

    except:
        return None

def print_submission(submission: dict[str, Any]) -> None:
    print("[SUBMISSION]")
    print(json.dumps(submission, indent = 4))

def handle_submission(proposal_state: dict[str, Any]) -> None:
    if proposal_state["state"] != "submission":
        return

    submission = proposal_state["submission"]

    if proposal_state["type"] == "experiment":
        submit_experiment(submission)
        return

    print_submission(submission)

def prompt_user() -> str:
    while True:
        prompt = input("Prompt: ").strip()

        if prompt:
            return prompt

        print("Prompt cannot be empty.")


def build_agent_system() -> AgentSystem:
    from agents.agent_system import AgentSystem, Agent

    models = ["deepseek/deepseek-v3.2", "moonshotai/kimi-k2.5", "qwen/qwen3.5-plus-02-15"]
    subagent_models = ["deepseek/deepseek-v3.2", "moonshotai/kimi-k2.5", "qwen/qwen3.5-plus-02-15"]

    return AgentSystem(
        agents = [
            Agent(
                id = "Deepseek",
                max_context_len = 15,
                n_delete = 5,
                chat_models = models,
                summarize_models = models
            )
        ],
        subagent_pool = [
            Agent(
                id = "Subagent",
                max_context_len = 10,
                n_delete = 3,
                chat_models = subagent_models,
                summarize_models = subagent_models
            )
        ]
    )


def run_loop(agents: AgentSystem) -> None:
    state = load_state()

    prompt = prompt_user()
    while True:
        state = agents.run(state, prompt)
        handle_submission(state["proposal_state"])
        prompt = prompt_user()

        


if __name__ == "__main__":
    from openrouter import OpenRouter

    dotenv.load_dotenv("../../.env", override = True)

    agents = build_agent_system()
    open_router = OpenRouter(
        api_key = os.environ["OPENROUTER_KEY"]
    )
    agents.build_graph(open_router)
    run_loop(agents)
