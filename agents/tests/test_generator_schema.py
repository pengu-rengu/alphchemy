import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from dataframe_parse import parse_experiment
from generator.generators import ExperimentGen
from generator.load import load_generator


def generator_json() -> dict:
    path = Path(__file__).resolve().parents[1] / "src" / "generator.json"
    with open(path, "r") as file:
        return json.load(file)


def experiment_json() -> dict:
    return {
        "val_size": 0.15,
        "test_size": 0.15,
        "cv_folds": 2,
        "fold_size": 0.5,
        "backtest_schema": {
            "start_offset": 5,
            "start_balance": 10000.0,
            "delay": 1
        },
        "strategy": {
            "global_max_positions": 4,
            "feats": [
                {
                    "feature": "constant",
                    "id": "const_1",
                    "constant": 1.0
                }
            ],
            "stop_conds": {
                "max_iters": 3,
                "train_patience": 5,
                "val_patience": 5
            },
            "opt": {
                "type": "genetic",
                "pop_size": 10,
                "seq_len": 5,
                "n_elites": 2,
                "mut_rate": 0.1,
                "cross_rate": 0.7,
                "tournament_size": 3
            },
            "entry_schemas": [
                {
                    "node_ptr": {"anchor": "from_end", "idx": 0},
                    "position_size": 0.1,
                    "max_positions": 3
                }
            ],
            "exit_schemas": [
                {
                    "node_ptr": {"anchor": "from_end", "idx": 0},
                    "entry_indices": [0],
                    "stop_loss": 0.05,
                    "take_profit": 0.05,
                    "max_hold_time": 20
                }
            ],
            "base_net": {
                "type": "logic",
                "nodes": [
                    {
                        "type": "input",
                        "threshold": 0.5,
                        "feat_idx": 0
                    }
                ],
                "default_value": False
            },
            "actions": {
                "type": "logic",
                "n_thresholds": 5,
                "allow_recurrence": False,
                "allowed_gates": ["and", "or"],
                "meta_actions": []
            },
            "penalties": {
                "type": "logic",
                "node": 0.0,
                "input": 0.0,
                "gate": 0.0,
                "recurrence": 0.0,
                "feedforward": 0.0,
                "used_feat": 0.0,
                "unused_feat": 0.0
            }
        }
    }


def test_load_default_generator_includes_global_max_positions():
    generator, search_space = load_generator("generator.json")

    assert generator.strategy.global_max_positions == 3
    assert isinstance(search_space, dict)


def test_generator_requires_global_max_positions():
    data = generator_json()
    del data["generator"]["strategy"]["global_max_positions"]

    with pytest.raises(ValidationError):
        ExperimentGen.model_validate(data["generator"])


def test_parse_experiment_records_global_max_positions():
    row = {}

    parse_experiment(row, experiment_json())

    assert row["global_max_positions"] == 4.0
