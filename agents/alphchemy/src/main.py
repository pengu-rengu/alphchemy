from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

import dotenv
from agents.data_paths import ensure_parent_dir, generated_path, state_path
from generator.generators import ExperimentGen
from generator.params import ParamSpace

STATE_PATH = state_path()

def generate_experiments(submission: dict[str, Any]) -> list[dict[str, Any]]:
    experiment_gen = ExperimentGen.model_validate(submission["generator"])
    param_space = ParamSpace.model_validate(submission["param_space"])
    return param_space.generate_experiments(experiment_gen, 1000)


def write_experiments(path: Path, experiments: list[dict[str, Any]]) -> None:
    ensure_parent_dir(path)

    with open(path, "a") as file:
        for experiment in experiments:
            json.dump(experiment, file)
            file.write("\n")


def execute_generator(submission: dict[str, Any], output_path: Path | None = None) -> int:
    experiments = generate_experiments(submission)
    target_path = output_path

    if target_path is None:
        target_path = generated_path()

    write_experiments(target_path, experiments)
    return len(experiments)


def load_state() -> dict[str, Any] | None:
    try:
        with open(STATE_PATH, "r") as file:
            return json.load(file)
        
    except:
        return None

def print_submission(submission: dict[str, Any]) -> None:
    print("[SUBMISSION]")
    print(json.dumps(submission, indent = 4))

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
        
        submission = state["proposal_state"]["submission"]
        print_submission(submission)
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
