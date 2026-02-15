from concept import ConceptFactory
from ontology import OntologyFactory
from sae import SparseAutoencoder, HyperParams
from dataclasses import asdict
import pandas as pd
import json

if __name__ == "__main__":
    experiments_df = pd.read_csv("data/experiments.csv")
    results_df = pd.read_csv("data/results.csv")

    df = pd.concat([experiments_df, results_df], axis = 1)

    hyper_params = HyperParams(
        latent_dim = 100,
        learning_rate = 0.001,
        batch_size = 32,
        max_epochs = 1000,
        l1_lambda = 0.1,
        val_size = 0.2,
        patience = 10
    )

    model = SparseAutoencoder(df.shape[1], hyper_params)
    results = model.fit(df)
    latent = model.predict(df)

    concecpt_factory = ConceptFactory(
        min_k = 2,
        max_k = 2,
        max_cols = 10,
        coverage_threshold = 0.5,
        activation_threshold = 0.0
    )
    concepts = concecpt_factory.make_concepts(latent, experiments_df)

    ontology_factory = OntologyFactory(
        result_metric = "test_excess_sharpe_mean",
        significance_threshold = 1.0,
        jaccard_threshold = 0.0,
        max_edges = 1000,
        max_hypotheses = 1000
    )
    ontology = ontology_factory.make_ontology(concepts, results_df)
    
    print("Converting to json...")

    ontology_json = ontology.to_json()

    print(json.loads(json.dumps(ontology_json, indent = 4)))

    with open("data/ontology.json", 'w') as file:
        json.dump(ontology_json, file, indent = 4)

    


    
