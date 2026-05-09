final Map<String, dynamic> mockExperimentJson = {
  "val_size": 0.2,
  "test_size": 0.1,
  "cv_folds": 4,
  "fold_size": 0.25,
  "backtest_schema": {
    "start_offset": 200,
    "start_balance": 50000.0,
    "delay": 2
  },
  "strategy": {
    "global_max_positions": 5,
    "feats": [
      {
        "feature": "constant",
        "id": "bias",
        "constant": 0.0
      },
      {
        "feature": "raw_returns",
        "id": "log_close",
        "returns_type": "log",
        "ohlc": "close"
      },
      {
        "feature": "raw_returns",
        "id": "simple_close",
        "returns_type": "simple",
        "ohlc": "close"
      }
    ],
    "base_net": {
      "type": "logic",
      "nodes": [
        {
          "id": "in_bias",
          "type": "input",
          "threshold": null,
          "feat_id": "bias"
        },
        {
          "id": "in_log_close",
          "type": "input",
          "threshold": null,
          "feat_id": "log_close"
        },
        {
          "id": "gate_signal",
          "type": "gate",
          "gate": null,
          "in1_idx": null,
          "in2_idx": null
        }
      ],
      "default_value": false
    },
    "actions": {
      "type": "logic",
      "meta_actions": [
        {
          "id": "act_new_input",
          "label": "act_new_input",
          "sub_actions": ["set_feat", "set_threshold"]
        },
        {
          "id": "act_new_gate",
          "label": "act_new_gate",
          "sub_actions": ["set_gate", "set_in1_idx", "set_in2_idx"]
        }
      ],
      "thresholds": [
        {
          "id": "thr_bias",
          "feat_id": "bias",
          "min": -1.0,
          "max": 1.0
        },
        {
          "id": "thr_log_close",
          "feat_id": "log_close",
          "min": -0.08,
          "max": 0.08
        },
        {
          "id": "thr_simple_close",
          "feat_id": "simple_close",
          "min": -0.1,
          "max": 0.1
        }
      ],
      "feat_order": ["bias", "log_close", "simple_close"],
      "n_thresholds": 8,
      "allow_recurrence": false,
      "allowed_gates": ["and", "or"]
    },
    "penalties": {
      "type": "logic",
      "node": 0.002,
      "input": 0.001,
      "gate": 0.003,
      "recurrence": 0.05,
      "feedforward": 0.0,
      "used_feat": 0.0,
      "unused_feat": 0.01
    },
    "stop_conds": {
      "max_iters": 150,
      "train_patience": 12,
      "val_patience": 12
    },
    "opt": {
      "type": "genetic",
      "pop_size": 80,
      "seq_len": 15,
      "n_elites": 5,
      "mut_rate": 0.05,
      "cross_rate": 0.7,
      "tournament_size": 3
    },
    "entry_schemas": [
      {
        "id": "entry_long",
        "node_ptr": {
          "anchor": "from_end",
          "idx": 0
        },
        "position_size": 0.1,
        "max_positions": 5
      }
    ],
    "exit_schemas": [
      {
        "id": "exit_long",
        "node_ptr": {
          "anchor": "from_end",
          "idx": 0
        },
        "entry_ids": ["entry_long"],
        "stop_loss": 0.03,
        "take_profit": 0.06,
        "max_hold_time": 30
      }
    ]
  }
};
