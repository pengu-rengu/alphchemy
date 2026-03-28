from agents.agent_system import AgentSystem, Agent
from openrouter import OpenRouter
import os
import redis
import dotenv
import threading

if __name__ == "__main__":
    dotenv.load_dotenv("../.env", override = True)

    models = ["deepseek/deepseek-v3.2", "moonshotai/kimi-k2.5", "qwen/qwen3.5-plus-02-15"]
    subagent_models = ["deepseek/deepseek-v3.2", "moonshotai/kimi-k2.5", "qwen/qwen3.5-plus-02-15"]
    agents = AgentSystem(
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

    open_router = OpenRouter(
        api_key = os.environ["OPENROUTER_KEY"]
    )

    redis_client = redis.Redis()

    agents.build_graph(open_router, redis_client)
    agents.run()
