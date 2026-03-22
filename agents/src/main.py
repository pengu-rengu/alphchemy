from agents.agent_system import AgentSystem, Agent
from agents.commands import CommandConstraints
from ontology.ontology import OntologyFactory
from ontology.concept import ConceptFactory
from ontology.sae import HyperParams
from ontology.updater import OntologyUpdater
from openrouter import OpenRouter
import os
import redis
import dotenv
import threading

if __name__ == "__main__":
    dotenv.load_dotenv("../.env", override = True)

    hyper_params = HyperParams(
        latent_dim = 150,
        learning_rate = 0.001,
        batch_size = 32,
        max_epochs = 1000,
        l1_lambda = 0.3,
        val_size = 0.2,
        patience = 10
    )
    concept_factory = ConceptFactory(
        min_k = 2,
        max_k = 3,
        max_cols = 5,
        coverage_threshold = 0.5,
        activation_threshold = 0.0
    )
    ontology_factory = OntologyFactory(
        result_metric = "test_excess_sharpe_mean",
        significance_threshold = 0.05,
        jaccard_threshold = 0.5,
        max_edges = 1000,
        max_hypotheses = 1000
    )
    models = ["deepseek/deepseek-v3.2", "moonshotai/kimi-k2.5", "qwen/qwen3.5-plus-02-15"]
    subagent_models = ["deepseek/deepseek-v3.2", "moonshotai/kimi-k2.5", "qwen/qwen3.5-plus-02-15"]
    agents = AgentSystem(
        agents = [
            Agent(
                id = "Deepseek",
                max_context_len = 15,
                n_delete = 5,
                chat_models = models,
                summarize_models = models,
                command_constraints = CommandConstraints(
                    max_traversal_count = 10
                )
            )
        ],
        subagent_pool = [
            Agent(
                id = "Subagent",
                max_context_len = 10,
                n_delete = 3,
                chat_models = subagent_models,
                summarize_models = subagent_models,
                command_constraints = CommandConstraints(
                    max_traversal_count = 5
                )
            )
        ]
    )
    updater = OntologyUpdater(
        ontology_factory = ontology_factory,
        concept_factory = concept_factory,
        sae_hyper_params = hyper_params,
        max_experiments = 50_000,
        truncate_freq = 5000,
        rebuild_freq = 50_000
    )

    open_router = OpenRouter(
        api_key = os.environ["OPENROUTER_KEY"]
    )

    redis_client = redis.Redis()

    updater.initialize(redis_client)    
    agents.build_graph(updater, open_router, redis_client)

    #updater_thread = threading.Thread(target = updater.run)
    #updater_thread.start()

    agents_thread = threading.Thread(target = agents.run)
    agents_thread.start()

    #updater_thread.join()
    agents_thread.join()

