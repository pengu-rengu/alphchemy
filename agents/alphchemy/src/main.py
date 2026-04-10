from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

import dotenv
from agents.agent_system import AgentSystem, Agent
from agents.data_paths import ensure_parent_dir, generated_path, state_path
from generator.generators import ExperimentGen
from generator.params import ParamSpace
from run_generator import GeneratorRunner
from openrouter import OpenRouter

STATE_PATH = state_path()

def generate_experiments(submission: dict[str, Any]) -> list[dict[str, Any]]:
    experiment_gen = ExperimentGen.model_validate(submission["generator"])
    param_space = ParamSpace.model_validate(submission["param_space"])
    return param_space.generate_experiments(experiment_gen, 1000)


def execute_generator(submission: dict[str, Any], output_path: Path | None = None) -> int:
    experiments = generate_experiments(submission)
    target_path = output_path

    if target_path is None:
        target_path = generated_path()

    GeneratorRunner.write_experiments(target_path, experiments, append = True)
    return len(experiments)


def load_state() -> dict[str, Any]:
    with open(STATE_PATH, "r") as file:
        return json.load(file)


def save_state(state: dict[str, Any]) -> None:
    ensure_parent_dir(STATE_PATH)

    with open(STATE_PATH, "w") as file:
        json.dump(state, file, indent = 4)


def approve_submission() -> None:
    state = load_state()
    state["proposal_state"] = {"state": "idle"}
    save_state(state)

def reject_submission(reason: str) -> None:
    stripped_reason = reason.strip()

    if not stripped_reason:
        raise ValueError("Rejection reason cannot be empty")

    state = load_state()
    state["proposal_state"] = {
        "state": "rejection",
        "reason": stripped_reason
    }
    save_state(state)

def print_submission(submission: dict[str, Any]) -> None:
    print("[SUBMISSION]")
    print(json.dumps(submission, indent = 4))

def prompt_rejection_reason() -> str:
    while True:
        reason = input("Reason: ").strip()

        if reason:
            return reason

        print("Rejection reason cannot be empty.")

def prompt_submission_decision(submission: dict[str, Any]) -> tuple[bool, str | None]:
    print_submission(submission)

    while True:
        decision = input("Approve or reject? [a/r]: ").strip().lower()

        if decision in ["a", "approve"]:
            return True, None

        if decision in ["r", "reject"]:
            reason = prompt_rejection_reason()
            return False, reason

        print("Please enter `a` to approve or `r` to reject.")

def run_with_review(agents: AgentSystem, prompt: str) -> None:
    while True:
        result = agents.run_turn(prompt)
        submission = result["submission"]
        submission_type = result["type"]
        approved, reason = prompt_submission_decision(submission)

        if approved:
            if submission_type == "generator":
                count = execute_generator(submission)
                print(f"Queued {count} experiments.")
            else:
                print("[REPORT]")
                print(submission["report"])

            approve_submission()
        else:
            reject_submission(reason or "")


def build_agent_system() -> AgentSystem:

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


def main() -> None:
    from openrouter import OpenRouter

    dotenv.load_dotenv("../.env", override = True)

    agents = build_agent_system()
    open_router = OpenRouter(
        api_key = os.environ["OPENROUTER_KEY"]
    )
    prompt = input("Prompt: ").strip()

    agents.build_graph(open_router)

    run_with_review(agents, prompt)

if __name__ == "__main__":

    dotenv.load_dotenv("../../.env", override = True)

    agents = build_agent_system()
    open_router = OpenRouter(
        api_key = os.environ["OPENROUTER_KEY"]
    )
    prompt = input("Prompt: ").strip()

    agents.build_graph(open_router)

    run_with_review(agents, prompt)
