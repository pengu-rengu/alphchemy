from ontology.ontology import OntologyFactory
from ontology.concept import ConceptFactory
from ontology.sae import HyperParams
from ontology.updater import OntologyUpdater

if __name__ == "__main__":
    concept_factory = ConceptFactory(
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
    hyper_params = HyperParams(
        latent_dim = 150,
        learning_rate = 0.001,
        batch_size = 32,
        max_epochs = 1000,
        l1_lambda = 0.3,
        val_size = 0.2,
        patience = 10
    )
    updater = OntologyUpdater(
        ontology_factory = ontology_factory,
        concept_factory = concept_factory,
        sae_hyper_params = hyper_params,
        max_experiments = 50_000,
        truncate_freq = 5000,
        rebuild_freq = 50_000
    )

    updater.build_dataframes()