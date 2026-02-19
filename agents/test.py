from ontology.concept import ConceptFactory
from ontology.ontology import OntologyFactory
from agents.ontology.sae import SparseAutoencoder, HyperParams
import pandas as pd
import json

if __name__ == "__main__":
    experiments_df = pd.read_csv("data/experiments.csv")
    results_df = pd.read_csv("data/results.csv")

    

    
