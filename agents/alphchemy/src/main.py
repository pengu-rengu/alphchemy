from __future__ import annotations

from typing import Any
from agents.agent_system import AgentSystem, Agent
from agents.data_paths import state_path, ensure_parent_dir
from openrouter import OpenRouter
import os
import dotenv
import json
from run_generator import ExperimentGen, ParamSpace

STATE_PATH = state_path()

def execute_generator(generator_json: dict[str, Any], search_space: dict[str, list[Any]]) -> int:
    experiment_gen = ExperimentGen.model_validate(generator_json)
    param_space = ParamSpace(search_space = search_space)
    experiments = param_space.generate_experiments(experiment_gen, 1000)

    for experiment in experiments:
        serialized = json.dumps(experiment)
        #redis_client.lpush("experiments", serialized)

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
    state["commands"] = []
    state["params"] = []
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
    state["commands"] = []
    state["params"] = []
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
        result = agents.run(prompt)
        submission = result["submission"]
        submission_type = result["type"]
        approved, reason = prompt_submission_decision(submission)

        if approved:
            if submission_type == "generator":
                
                print(f"Queued experiments.")
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

    dotenv.load_dotenv("../.env", override = True)

    agents = build_agent_system()
    open_router = OpenRouter(
        api_key = os.environ["OPENROUTER_KEY"]
    )
    prompt = input("Prompt: ").strip()

    agents.build_graph(open_router)

    run_with_review(agents, prompt)

if __name__ == "__main__":
    main()
