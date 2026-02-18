import pandas as pd
import json
from ontology.parserow import parse_experiment, parse_results

def build_dataframes() -> tuple[pd.DataFrame, pd.DataFrame]:
    experiment_rows = []
    results_rows = []

    with open("data/experiments.jsonl", 'r') as file:
        for i, line in enumerate(file):
            
            if not line.strip():
                continue
            
            print(f"Reading line {i + 1}")

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
                print(f"Skipping invalid JSON at line {i+1}")
            except Exception as e:
                print(f"Error parsing line {i+1}: {e}")

    experiments_df = pd.DataFrame(experiment_rows, dtype = float)
    results_df = pd.DataFrame(results_rows, dtype = float)
    return experiments_df, results_df

if __name__ == "__main__":

    experiments_df, results_df = build_dataframes()

    print("Saving...")

    experiments_df.to_csv("data/experiments.csv", index = False)
    results_df.to_csv("data/results.csv", index = False)

    print("Done.")