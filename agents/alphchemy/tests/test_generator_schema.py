import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from dataframe_parse import parse_experiment
from generator.generators import ExperimentGen
from generator.load import load_generator
from generator.params import ParamSpace


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
                    "id": "entry_1",
                    "node_ptr": {"anchor": "from_end", "idx": 0},
                    "position_size": 0.1,
                    "max_positions": 3
                }
            ],
            "exit_schemas": [
                {
                    "id": "exit_1",
                    "node_ptr": {"anchor": "from_end", "idx": 0},
                    "entry_ids": ["entry_1"],
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
                        "feat_id": "const_1"
                    }
                ],
                "default_value": False
            },
            "actions": {
                "type": "logic",
                "feat_order": ["const_1"],
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


def test_load_generator_accepts_frontend_param_space_schema(tmp_path: Path):
    payload = {
        "generator": generator_json()["generator"],
        "param_space": {
            "search_space": {
                "mut_rate": [0.02, 0.05]
            }
        }
    }
    path = tmp_path / "frontend_wrapper.json"

    with open(path, "w") as file:
        json.dump(payload, file)

    generator, search_space = load_generator(str(path))

    assert generator.strategy.global_max_positions == 3
    assert search_space == {
        "mut_rate": [0.02, 0.05]
    }


def test_generator_requires_global_max_positions():
    data = generator_json()
    del data["generator"]["strategy"]["global_max_positions"]

    with pytest.raises(ValidationError):
        ExperimentGen.model_validate(data["generator"])


def test_generate_experiments_select_pool_items_by_id():
    generator, search_space = load_generator("generator.json")
    param_space = ParamSpace(search_space = search_space)

    experiments = param_space.generate_experiments(generator, 1)
    experiment = experiments[0]
    strategy = experiment["strategy"]
    base_net = strategy["base_net"]

    assert [node["id"] for node in base_net["nodes"]] == [
        "input_const_one",
        "input_const_half",
        "input_log_close",
        "input_simple_close",
        "input_log_high",
        "gate_first_pair",
        "gate_second_pair",
        "gate_merge_pairs",
        "gate_merge_high"
    ]
    assert [feat["id"] for feat in strategy["feats"]] == [
        "const_one",
        "const_half",
        "log_close",
        "simple_close",
        "log_high",
        "log_low",
        "log_open",
        "simple_high"
    ]
    assert strategy["entry_schemas"][0]["id"] == "entry_primary"
    assert strategy["exit_schemas"][0]["id"] == "exit_primary"
    assert strategy["exit_schemas"][0]["entry_ids"] == ["entry_primary"]


def test_generate_experiments_reject_duplicate_pool_ids():
    data = generator_json()
    data["generator"]["strategy"]["feat_pool"][1]["id"] = "const_one"

    generator = ExperimentGen.model_validate(data["generator"])
    param_space = ParamSpace(search_space = data["search_space"])

    with pytest.raises(ValueError):
        param_space.generate_experiments(generator, 1)


def test_generate_experiments_reject_unknown_selected_id():
    data = generator_json()
    data["generator"]["strategy"]["feat_selection"] = ["missing_feat"]

    generator = ExperimentGen.model_validate(data["generator"])
    param_space = ParamSpace(search_space = data["search_space"])

    with pytest.raises(ValueError):
        param_space.generate_experiments(generator, 1)


def test_parse_experiment_records_global_max_positions():
    row = {}

    parse_experiment(row, experiment_json())

    assert row["global_max_positions"] == 4.0
    assert row["entry_ids_count_count"] == 1.0


def test_parse_experiment_uses_feat_id_columns():
    row = {}
    experiment = experiment_json()
    experiment["strategy"]["actions"]["meta_actions"] = [
        {
            "label": "new_input",
            "sub_actions": ["set_feat", "set_threshold"]
        }
    ]

    parse_experiment(row, experiment)

    assert row["set_feat_ids"] == 1.0
    assert row["unset_feat_ids"] == 0.0
    assert row["set_feat_count"] == 1.0
    assert "set_feat_idx_count" not in row
