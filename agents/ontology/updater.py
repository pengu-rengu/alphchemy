from ontology.ontology import Ontology, OntologyFactory, parse_ontology
from ontology.concept import ConceptFactory
from ontology.sae import SparseAutoencoder, HyperParams
from ontology.parse_row import parse_experiment, parse_results
from pydantic import BaseModel, Field, model_validator, ConfigDict
from typing import Annotated
import pandas as pd
import redis
import json
import os
import shutil

class OntologyUpdater(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed = True)

    ontology_factory: OntologyFactory
    concept_factory: ConceptFactory
    sae_hyper_params: HyperParams
    max_experiments: Annotated[int, Field(ge = 1)]
    truncate_freq: Annotated[int, Field(ge = 1)]
    rebuild_freq: Annotated[int, Field(ge = 1)]
    
    rebuilt: Annotated[bool, Field(default = False, exclude = True)]

    redis_client: Annotated[redis.Redis | None, Field(default = None, exclude = True)]
    ontology: Annotated[Ontology | None, Field(default = None, exclude = True)]

    @model_validator(mode = "after")
    def validate_freqs(self):
        if self.rebuild_freq <= self.truncate_freq:
            raise ValueError("Rebuild frequency must be greater than truncate frequency")

        return self

    def initialize(self, redis_client: redis.Redis) -> Ontology:
        self.redis_client = redis_client
        
        if os.path.exists("data/ontology.json"):

            with open("data/ontology.json", "r") as file:
                ontology_json = json.load(file)
            
            self.ontology = parse_ontology(ontology_json)

        else:

            self.build_ontology()
        
        return self.ontology

    def build_dataframes(self) -> tuple[pd.DataFrame, pd.DataFrame]:
        experiment_rows = []
        results_rows = []

        with open("data/experiments.jsonl", 'r') as file:
            for i, line in enumerate(file):
                
                print(f"Parsing line {i+1}")

                if not line.strip():
                    continue

                try:
                    data = json.loads(line)

                    experiment = {}
                    results = {}

                    parse_experiment(experiment, data["experiment"])
                    parse_results(results, data["results"])

                    experiment["id"] = i
                    results["id"] = i

                    experiment_rows.append(experiment)
                    results_rows.append(results)

                except json.JSONDecodeError:
                    pass
                    print(f"Skipping invalid JSON at line {i+1}")
                except Exception as e:
                    pass
                    print(f"Error parsing line {i+1}: {e}")

        experiments_df = pd.DataFrame(experiment_rows, dtype = float)
        results_df = pd.DataFrame(results_rows, dtype = float)

        return experiments_df, results_df

    def build_ontology(self):
        experiments_df, results_df = self.build_dataframes()

        df = pd.concat([experiments_df, results_df], axis = 1)
        df.drop("id", axis = 1, inplace = True)
        
        model = SparseAutoencoder(df.shape[1], self.sae_hyper_params)
        results = model.fit(df)
        latent = model.predict(df)
        
        concepts = self.concept_factory.make_concepts(latent, experiments_df)

        self.ontology = self.ontology_factory.make_ontology(concepts, results_df)
        ontology_json = self.ontology.to_json()

        with open("data/ontology.json", "w") as file:
            json.dump(ontology_json, file)

    def truncate_experiments(self):

        print("Truncating experiments")

        with open("data/experiments.jsonl", "r") as file:
            n_lines = sum(1 for _ in file)

        if n_lines <= self.max_experiments:
            return
        
        n_delete = n_lines - self.max_experiments

        with open("data/experiments.jsonl", "r") as f_read, open("data/temp.jsonl", "w") as f_write:

            for _ in range(n_delete):
                next(f_read, None)

            for line in f_read:
                f_write.write(line)

        os.remove("data/experiments.jsonl")
        shutil.move("data/temp.jsonl", "data/experiments.jsonl")

    def check_rebuilt(self):
        if self.rebuilt:
            self.rebuilt = False
            return True
        
        return False
    
    def run(self):

        truncate_counter = 0
        rebuild_counter = 0

        while True:
            _, data = self.redis_client.brpop("results")
            entry = json.loads(data)

            truncate_counter += 1
            rebuild_counter += 1

            with open("data/experiments.jsonl", "a") as file:
                json.dump(entry, file)
                file.write("\n")

            if truncate_counter >= self.truncate_freq:
                self.truncate_experiments()
                truncate_counter = 0

            if rebuild_counter >= self.rebuild_freq:
                self.build_ontology()

                self.rebuilt = True
                rebuild_counter = 0
                
