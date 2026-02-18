import json
from langgraph.types import Overwrite
from agents.agent_system import AgentSystem
from ontology.ontology import parse_ontology
from agents.state import make_system_prompt
from openrouter import OpenRouter
import json
import dotenv
import os
import redis

def load_initial_state() -> dict:
    with open("data/state.json", "r") as file:
        initial_state = json.load(file)
    return initial_state

def create_initial_state() -> dict:
    system_prompts = {}

    for agent_id in ["Agent 1", "Agent 2"]:
        system_prompts[agent_id] = make_system_prompt(["Agent 1", "Agent 2"], agent_id, "")
    
    
    initial_state = {
        "agent_order": ["Agent 1", "Agent 2"],
        "turn": 0,
        "system_prompts": system_prompts,
        "summaries": {
            aid: "" for aid in ["Agent 1", "Agent 2"]
        },
        "agent_contexts": {
            aid: [
                {
                    "role": "user",
                    "personal_output": "[SYSTEM] You recommended first command is to send a greeting to your fellow agents.",
                    "global_output": ""
                }
            ] for aid in ["Agent 1", "Agent 2"]
        },
        "commands": [],
        "params": [],
        "proposal": None,
        "proposal_agent": None,
        "votes": [],
        "experiments_running": False,
        "n_rounds": 0
    }

    return initial_state

if __name__ == "__main__":
    dotenv.load_dotenv(".env", override = True)

    with open("data/ontology.json", "r") as file:
        ontology_json = json.load(file)
    
    ontology = parse_ontology(ontology_json)

    open_router = OpenRouter(
        api_key = os.environ["OPENROUTER_KEY"]
    )

    redis_client = redis.Redis()

    agents = AgentSystem(
        max_context_len = 15,
        delete_frac = 0.5,
        models = ["deepseek/deepseek-v3.2", "moonshotai/kimi-k2.5", "qwen/qwen3.5-plus-02-15"]
    )
    agents.build_graph(ontology, open_router, redis_client)

    initial_state = create_initial_state()
    
    agents.run(initial_state)