# Experiment Description

__Constraints__:
- Feature ids must be unique
- Logic penalties cannot be paired with decision networks
- Decision penalties cannot be paired with logic networks
- Fast windows must be <= slow windows
- Feature indices must be <= # of features
- Every feature must have a corresponding threshold range
- in1/in2/true/false/ref indices must be <= # of nodes
- Feature id in a threshold range object must exist
- Max > min in a threshold range object
- Meta actions cannot have other meta actions as sub actions
- Genetic `n_elites` and `tournament_size` must be <= `population_size`
- `val_size` + `test_size` must be < 1.0
- `entry_schemas` must not be empty
- `exit_schemas` must not be empty
- `entry_indices` values must be < length of `entry_schemas`

__Notes__:
- Indices are 0-based. null means unset.
- "Normalized" means divided by close price

__Experiment JSON schema__:

Feature Object:

{
    "feature": "constant",
    "id": str,
    "constant": float
}

OR

{
    "feature": "raw_returns",
    "id": str,
    "returns_type": any of "simple", "log",
    "ohlc": any of "open", "high", "low", "close"
}

Node Pointer Object:
{
    "anchor": any of "from_start", "from_end",
    "idx": int >= 0
}

Logic Node Object:

{
    "type": "input",
    "threshold": float,
    "feat_idx": null or int >= 0
}

OR

{
    "type": "gate",
    "gate": any of "and", "or", "xor", "nand", "nor", "xnor",
    "in1_idx": null or int >= 0,
    "in2_idx": null or int >= 0
}

Decision Node Object:

{
    "type": "branch",
    "threshold": float,
    "feat_idx": null or int >= 0,
    "true_idx": null or int >= 0,
    "false_idx": null or int >= 0
}

OR

{
    "type": "ref",
    "ref_idx": null or int >= 0,
    "true_idx": null or int >= 0,
    "false_idx": null or int >= 0
}

Network Object:

{
    "type": "logic",
    "nodes": [array of logic node objects],
    "default_value": bool
}

OR

{
    "type": "decision",
    "nodes": [array of decision node objects],
    "max_trail_len": int > 0,
    "default_value": bool
}

Penalties Object:

{
    "type": "logic",
    "node": float >= 0.0,
    "input": float >= 0.0,
    "gate": float >= 0.0,
    "recurrence": float >= 0.0,
    "feedforward": float >= 0.0,
    "used_feat": float >= 0.0,
    "unused_feat": float >= 0.0
}

OR

{
    "type": "decision",
    "node": float >= 0.0,
    "branch": float >= 0.0,
    "ref": float >= 0.0,
    "leaf": float >= 0.0,
    "non_leaf": float >= 0.0,
    "used_feat": float >= 0.0,
    "unused_feat": float >= 0.0
}

Threshold Range Object:

{
    "feat_id": str,
    "min": float,
    "max": float
}


Logic Meta Action Object:

{
    "label": Action enum value,
    "sub_actions": [array containing any of "next_feat", "next_threshold", "next_node", "select_node", "next_gate", "set_feat_idx", "set_threshold", "set_gate", "set_in1_idx", "set_in2_idx", "new_input", "new_gate"]
}

Decision Meta Action Object:

{
    "label": Action enum value,
    "sub_actions": [array containing any of "next_feat", "next_threshold", "next_node", "select_node", "set_feat_idx", "set_threshold", "set_true_idx", "set_false_idx", "set_ref_idx", "new_branch", "new_ref"]
}

Actions Object:

{
    "type": "logic",
    "meta_actions": [array of logic meta action objects],
    "thresholds": [array of threshold range objects],
    "n_thresholds": integer > 0,
    "allow_recurrence": boolean,
    "allowed_gates": [array containing any of "and", "or", "xor", "nand", "nor", "xnor"]
}

OR

{
    "type": "decision",
    "meta_actions": [array of decision meta action objects],
    "thresholds": [array of threshold range objects],
    "n_thresholds": integer > 0,
    "allow_refs": boolean
}

Stop Conditions Object:

{
    "max_iters": int > 0,
    "train_patience": int > 0,
    "val_patience": int > 0
}


Optimizer Object:

{
    "type": "genetic",
    "pop_size": int > 0,
    "seq_len": int > 0,
    "n_elites": int >= 0,
    "mut_rate": float 0.0 - 1.0,
    "cross_rate": float 0.0 - 1.0,
    "tournament_size": int > 0
}

Entry Schema Object:

{
    "node_ptr": node pointer object,
    "position_size": float > 0.0 and <= 1.0,
    "max_positions": int > 0
}

Exit Schema Object:

{
    "node_ptr": node pointer object,
    "entry_indices": [array of int >= 0, must be < entry_schemas length],
    "stop_loss": float > 0.0,
    "take_profit": float > 0.0,
    "max_hold_time": int > 0
}

Strategy Object:

{
    "base_net": network object,
    "feats": [array of feature objects],
    "actions": actions object,
    "penalties": penalties object,
    "stop_conds": stop conditions object,
    "opt": optimizer object,
    "entry_schemas": [array of entry schema objects],
    "exit_schemas": [array of exit schema objects]
}

Backtest Schema Object:

{
    "start_offset": int,
    "start_balance": float > 0.0,
    "delay": int
}

Experiment Object:

{
    "title": str,
    "val_size": float > 0.0,
    "test_size": float > 0.0,
    "cv_folds": int > 0,
    "fold_size": float > 0.0 and <= 1.0,
    "backtest_schema": backtest schema object,
    "strategy": strategy object
}

# Ontology description

- The Ontology is an abstraction of raw experiments and results data. The Ontology consists of Hypotheses, which are claims on whether experiments that satisfy a given set of conditions have a higher value of a given result metric than experiments that do not satisfy the conditions.
- Hypotheses are related to each other based on whether they validate/invalidate each other.
- If two hypotheses agree on whether the experiments that satisfy their conditions have a higher value of a given result metric than experiments that do not, and then jaccard similarity between experiments of the two hypotheses is sufficient, then the hypotheses validate each other.
- Otherwise the two hypothesis invalidate each other.