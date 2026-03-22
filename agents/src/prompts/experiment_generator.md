# Generator Documentation

To submit experiments, you provide a generator config and a search space. The system generates experiments by substituting all combinations of search space values into the generator template.

## ParamKey

Any field that should vary across experiments uses a ParamKey: `{"key": "param_name"}`. The corresponding key in the search space maps to a list of possible values. All combinations are generated via cartesian product, capped at 1000 experiments.

For example, if the search space is `{"x": [1, 2], "y": [true, false]}`, then 4 experiments are generated: (x=1, y=true), (x=1, y=false), (x=2, y=true), (x=2, y=false).

## Pools

Pools let you define a set of items and select a subset by index. The generator has 6 pool mappings:

- `feat_pool` + `feat_selection` -> `feats`
- `node_pool` + `node_selection` -> `nodes`
- `entry_pool` + `entry_selection` -> `entry_schemas`
- `exit_pool` + `exit_selection` -> `exit_schemas`
- `meta_action_pool` + `meta_action_selection` -> `meta_actions`
- `threshold_pool` + `threshold_selection` -> `thresholds`

The pool field is a list of items. The selection field is a list of 0-based indices (or a ParamKey resolving to one). During generation, the selected indices pick items from the pool, and the result uses the output name.

## Merge Fields

`NetworkGen`, `ActionsGen`, and `PenaltiesGen` each have a `type` field and paired sub-objects (e.g. `logic_net` and `decision_net`). During generation, only the sub-object whose name starts with the `type` value is kept, and its fields are merged into the parent object. The other sub-object is discarded.

For example, if `type` is `"logic"`, then `logic_net` is merged and `decision_net` is discarded.

Both sub-objects must always be present in the generator. Set the unused one to `null` if the type is fixed. If the type varies via ParamKey, both must be fully defined.

## Generator JSON Schema

ParamKey Object (usable in any field marked with "or ParamKey"):
```
{"key": str}
```

Feature Object:

```
{
    "feature": "constant",
    "id": str or ParamKey,
    "constant": float or ParamKey
}
```

OR

```
{
    "feature": "raw_returns",
    "id": str or ParamKey,
    "returns_type": str or ParamKey,
    "ohlc": str or ParamKey
}
```

Node Pointer Object:
```
{
    "anchor": str or ParamKey,
    "idx": int or ParamKey
}
```

Logic Node Object:

```
{
    "type": "input",
    "threshold": float or ParamKey or null,
    "feat_idx": int or ParamKey or null
}
```

OR

```
{
    "type": "gate",
    "gate": str or ParamKey or null,
    "in1_idx": int or ParamKey or null,
    "in2_idx": int or ParamKey or null
}
```

Decision Node Object:

```
{
    "type": "branch",
    "threshold": float or ParamKey or null,
    "feat_idx": int or ParamKey or null,
    "true_idx": int or ParamKey or null,
    "false_idx": int or ParamKey or null
}
```

OR

```
{
    "type": "ref",
    "ref_idx": int or ParamKey or null,
    "true_idx": int or ParamKey or null,
    "false_idx": int or ParamKey or null
}
```

Logic Network Object:
```
{
    "node_pool": [array of logic node objects],
    "node_selection": [array of int] or ParamKey,
    "default_value": bool or ParamKey
}
```

Decision Network Object:
```
{
    "node_pool": [array of decision node objects],
    "node_selection": [array of int] or ParamKey,
    "default_value": bool or ParamKey,
    "max_trail_len": int or ParamKey
}
```

Network Object (merge field: type determines which sub-object is kept):
```
{
    "type": str or ParamKey,
    "logic_net": logic network object or null,
    "decision_net": decision network object or null
}
```

Logic Penalties Object:
```
{
    "node": float or ParamKey,
    "input": float or ParamKey,
    "gate": float or ParamKey,
    "recurrence": float or ParamKey,
    "feedforward": float or ParamKey,
    "used_feat": float or ParamKey,
    "unused_feat": float or ParamKey
}
```

Decision Penalties Object:
```
{
    "node": float or ParamKey,
    "branch": float or ParamKey,
    "ref": float or ParamKey,
    "leaf": float or ParamKey,
    "non_leaf": float or ParamKey,
    "used_feat": float or ParamKey,
    "unused_feat": float or ParamKey
}
```

Penalties Object (merge field):
```
{
    "type": str or ParamKey,
    "logic_penalties": logic penalties object or null,
    "decision_penalties": decision penalties object or null
}
```

Threshold Range Object:
```
{
    "feat_id": str or ParamKey,
    "min": float or ParamKey,
    "max": float or ParamKey
}
```

Meta Action Object:
```
{
    "label": str or ParamKey,
    "sub_actions": list or ParamKey
}
```

Logic Actions Object:
```
{
    "meta_action_pool": [array of meta action objects],
    "meta_action_selection": [array of int] or ParamKey,
    "threshold_pool": [array of threshold range objects],
    "threshold_selection": [array of int] or ParamKey,
    "n_thresholds": int or ParamKey,
    "allow_recurrence": bool or ParamKey,
    "allowed_gates": list or ParamKey
}
```

Decision Actions Object:
```
{
    "meta_action_pool": [array of meta action objects],
    "meta_action_selection": [array of int] or ParamKey,
    "threshold_pool": [array of threshold range objects],
    "threshold_selection": [array of int] or ParamKey,
    "n_thresholds": int or ParamKey,
    "allow_refs": bool or ParamKey
}
```

Actions Object (merge field):
```
{
    "type": str or ParamKey,
    "logic_actions": logic actions object or null,
    "decision_actions": decision actions object or null
}
```

Stop Conditions Object:
```
{
    "max_iters": int or ParamKey,
    "train_patience": int or ParamKey,
    "val_patience": int or ParamKey
}
```

Optimizer Object:
```
{
    "type": "genetic",
    "pop_size": int or ParamKey,
    "seq_len": int or ParamKey,
    "n_elites": int or ParamKey,
    "mut_rate": float or ParamKey,
    "cross_rate": float or ParamKey,
    "tournament_size": int or ParamKey
}
```

Entry Schema Object:
```
{
    "node_ptr": node pointer object,
    "position_size": float or ParamKey,
    "max_positions": int or ParamKey
}
```

Exit Schema Object:
```
{
    "node_ptr": node pointer object,
    "entry_indices": list or ParamKey,
    "stop_loss": float or ParamKey,
    "take_profit": float or ParamKey,
    "max_hold_time": int or ParamKey
}
```

Backtest Schema Object:
```
{
    "start_offset": int or ParamKey,
    "start_balance": float or ParamKey,
    "delay": int or ParamKey
}
```

Strategy Object:
```
{
    "base_net": network object,
    "feat_pool": [array of feature objects],
    "feat_selection": [array of int] or ParamKey,
    "actions": actions object,
    "penalties": penalties object,
    "stop_conds": stop conditions object,
    "opt": optimizer object,
    "entry_pool": [array of entry schema objects],
    "entry_selection": [array of int] or ParamKey,
    "exit_pool": [array of exit schema objects],
    "exit_selection": [array of int] or ParamKey
}
```

Experiment Generator Object (top level):
```
{
    "title": str or ParamKey,
    "val_size": float or ParamKey,
    "test_size": float or ParamKey,
    "cv_folds": int or ParamKey,
    "fold_size": float or ParamKey,
    "backtest_schema": backtest schema object,
    "strategy": strategy object
}
```

## Search Space Format

The search space is a dict where each key is a string referenced by ParamKey objects, and each value is a list of possible values. The total number of experiments is the product of all list lengths, capped at 1000.

```
{
    "param_name_1": [value1, value2],
    "param_name_2": [value3, value4, value5]
}
```