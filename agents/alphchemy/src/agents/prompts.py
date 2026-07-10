from agents.state import AgentsState, get_agent_id

SCIENTIFIC_RIGOR = """\
- You do not accept empirical data at face value; you demand a causal theory from first principles. You decouple correlation from causation and strive to find the ground truth.
- You conduct thorough research of past experiments to understand what has and hasn't worked.
- You are extremely critical and never believe a statement without seeing evidence."""

COMPLIANCE = "- You adhere strictly to constraints, but you're not afraid to explore within those boundaries."

MULTI_ONLY = """\
__Devil's Advocate__:
- You are an independent thinker who resists groupthink. If other agents agree on a flawed premise, you will stand alone to correct it.
- You do not hesitate to critique your fellow agents and stress-test their ideas to find breaking points.
- You engage in steel manning. You reconstruct your opponents' arguments in their strongest possible form before making a counter argument.

__Pragmatic Communication__:
- Your messages are concise, mathematical, and evidence-based.
- You justify every assertion with reasoning or empirical data.
- You maximize information density. You don't send a message if it does not advance the logic or provide new data."""

SINGLE_COMPETENCIES = f"{SCIENTIFIC_RIGOR}\n{COMPLIANCE}"

MULTI_COMPETENCIES = f"""\
__Scientific Rigor__:
{SCIENTIFIC_RIGOR}

__Devil's Advocate__:
- You are an independent thinker who resists groupthink. If other agents agree on a flawed premise, you will stand alone to correct it.
- You do not hesitate to critique your fellow agents and stress-test their ideas to find breaking points.
- You engage in steel manning. You reconstruct your opponents' arguments in their strongest possible form before making a counter argument.

__Pragmatic Communication__:
- Your messages are concise, mathematical, and evidence-based.
- You justify every assertion with reasoning or empirical data.
- You maximize information density. You don't send a message if it does not advance the logic or provide new data.

__Compliance to constraints__:
{COMPLIANCE}"""

EXPERIMENT_RESULTS_NOTEBOOK_DESCRIPTION = """\
# Experiment Description

An Experiment defines a trading strategy and evaluates it via cross-validated backtesting. The strategy uses a boolean network to generate entry/exit signals from numerical features. A genetic algorithm optimizes the network structure by applying sequences of actions to a base network, maximizing the configured objective metrics on training data while validating on held-out data.

Constant Feature:
A feature that outputs the same fixed value for every bar.

- `id` (unique string): identifier for this feature
- `constant` (float): the value to output

Raw Returns Feature:
A feature that computes bar-to-bar price returns from OHLC data.

- `id` (unique string): identifier for this feature
- `returns_type` ("log" or "simple"): log returns use ln(price[i] / price[i-1]), simple returns use (price[i] / price[i-1]) - 1
- `ohlc` ("open", "high", "low", or "close"): which price series to compute returns from

Indicator Features:
OHLC-only technical indicators that output one numeric series per feature. Warm-up bars without enough history output 0.0.

- `normalized_sma`: `id`, `ohlc`, `window`; outputs SMA / price
- `normalized_ema`: `id`, `ohlc`, `window`, `smooth`; outputs EMA / price
- `normalized_macd`: `id`, `ohlc`, `fast_window`, `slow_window`, `signal_window`, `fast_smooth`, `slow_smooth`, `signal_smooth`, `output`; output is "line", "signal", or "hist"; outputs the selected component / price
- `rsi`: `id`, `ohlc`, `window`, `smooth`; outputs RSI from 0 to 100
- `normalized_bb`: `id`, `ohlc`, `window`, `std_multiplier`, `output`; output is "upper", "lower", or "width"; upper/lower output is (mean ± std_multiplier·σ) / price, width output is (2·std_multiplier·σ) / price
- `stochastic`: `id`, `window`, `smooth_window`, `output`; output is "percent_k" or "percent_d"; outputs values from 0 to 100 (uses high/low/close internally)
- `normalized_atr`: `id`, `window`, `smooth`; outputs ATR / close
- `roc`: `id`, `ohlc`, `window`; outputs price / lagged_price
- `normalized_dc`: `id`, `window`, `output`; output is "upper", "lower", "middle", or "width"; outputs the selected channel value / close

Node Pointer:
A reference to a node in a network, resolved to an absolute index at runtime.

- `anchor` ("from_start" or "from_end"): whether the index counts from the beginning or end of the node list
- `offset` (int >= 0): offset from the anchor

Logic Input Node:
A node that compares a feature value to a threshold, outputting true if the feature value exceeds the threshold.

- `threshold` (float or null): comparison threshold. null means unset, and the node outputs the network default value
- `feat_id` (string or null, must match a feature id): selected feature id. null means unset

Logic Gate Node:
A node that combines two input values using a boolean gate.

- `gate` ("and", "or", "xor", "nand", "nor", "xnor", or null): the boolean operation. null means unset
- `in1_idx` (int or null, < number of nodes): index of the first input node. null means unset, and the network default value is used
- `in2_idx` (int or null, < number of nodes): index of the second input node. null means unset, and the network default value is used

Logic Network:
A network of logic nodes evaluated sequentially by index. Each node reads its inputs from previously evaluated nodes (or the default value if unset) and writes its boolean output. Entry and exit signals are read from nodes referenced by node pointers.

- `nodes` (array of logic nodes): the ordered list of input and gate nodes
- `default_value` (bool): fallback value used when a node's inputs are unset or out of range

Decision Branch Node:
A node that compares a feature value to a threshold and branches to one of two child nodes based on the result.

- `threshold` (float or null): comparison threshold. null means unset
- `feat_id` (string or null, must match a feature id): selected feature id. null means unset
- `true_idx` (int or null, < number of nodes): node to visit if the comparison is true. null makes this a leaf in that direction
- `false_idx` (int or null, < number of nodes): node to visit if the comparison is false. null makes this a leaf in that direction

Decision Ref Node:
A node that copies another node's current boolean value and branches to one of two child nodes based on that value.

- `ref_idx` (int or null, < number of nodes): index of the node to reference. null means unset
- `true_idx` (int or null, < number of nodes): node to visit if the referenced value is true. null makes this a leaf
- `false_idx` (int or null, < number of nodes): node to visit if the referenced value is false. null makes this a leaf

Decision Network:
A tree of decision nodes. Evaluation starts at node 0 and follows branch/ref links until a leaf is reached or the trail length limit is hit. Signals are read from the trail of visited nodes via node pointers.

- `nodes` (array of decision nodes): the list of branch and ref nodes
- `max_trail_len` (int > 0): maximum number of nodes visited per evaluation step
- `default_value` (bool): fallback value used when inputs are unset or the trail is too short

Logic Penalties:
Penalty weights subtracted from the fitness score to penalize logic network complexity. Higher penalties discourage the corresponding structural element.

- `node` (float >= 0): penalty per node regardless of type
- `input` (float >= 0): additional penalty per input node
- `gate` (float >= 0): additional penalty per gate node
- `recurrence` (float >= 0): penalty per gate connection where the input index >= the gate's own index
- `feedforward` (float >= 0): penalty per gate connection where the input index < the gate's own index
- `used_feat` (float >= 0): penalty per feature that is referenced by at least one input node
- `unused_feat` (float >= 0): penalty per feature that is not referenced by any input node

Decision Penalties:
Penalty weights subtracted from the fitness score to penalize decision network complexity.

- `node` (float >= 0): penalty per node regardless of type
- `branch` (float >= 0): additional penalty per branch node
- `ref` (float >= 0): additional penalty per ref node
- `leaf` (float >= 0): penalty per null child pointer (leaf endpoint)
- `non_leaf` (float >= 0): penalty per non-null child pointer
- `used_feat` (float >= 0): penalty per feature referenced by at least one branch node
- `unused_feat` (float >= 0): penalty per feature not referenced by any branch node

Threshold Range:
Defines the min/max range for a feature's threshold values. The range is discretized into n_thresholds evenly spaced values that the optimizer can select from.

- `feat_id` (string, must match a feature id): the feature this range applies to
- `min` (float, < max): minimum threshold value
- `max` (float, > min): maximum threshold value

Meta Action:
A composite action that expands into a sequence of sub-actions when executed. Useful for defining higher-level operations.

- `label` (string): the action name that triggers this meta action
- `sub_actions` (array of strings): the sequence of actions to execute. Sub-actions cannot themselves be meta actions

Logic Actions:
Configuration for the set of actions available to the genetic algorithm when optimizing a logic network.

- `meta_actions` (array of meta action objects): composite actions available to the optimizer
- `thresholds` (array of threshold range objects, one per feature): threshold ranges for each feature
- `feat_order` (array of feature ids, one per feature): duplicate-free feature id order used by the internal feat cursor
- `n_thresholds` (int > 0): number of discrete threshold levels per feature range
- `allow_recurrence` (bool): whether gate nodes can reference nodes at the same or higher index
- `allowed_gates` (array of gate strings): which gate types the optimizer can assign

Decision Actions:
Configuration for the set of actions available to the genetic algorithm when optimizing a decision network.

- `meta_actions` (array of meta action objects): composite actions available to the optimizer
- `thresholds` (array of threshold range objects, one per feature): threshold ranges for each feature
- `feat_order` (array of feature ids, one per feature): duplicate-free feature id order used by the internal feat cursor
- `n_thresholds` (int > 0): number of discrete threshold levels per feature range
- `allow_refs` (bool): whether the optimizer can create new ref nodes

Stop Conditions:
Conditions that terminate the genetic algorithm optimization loop. The optimizer stops when any condition is met.

- `max_iters` (int > 0): maximum number of iterations
- `train_patience` (int >= 0): stop if no training score improvement for this many iterations
- `val_patience` (int >= 0): stop if no validation score improvement for this many iterations

Genetic Optimizer:
Configuration for the genetic algorithm that optimizes action sequences applied to the base network.

- `pop_size` (int > 0): number of action sequences in the population
- `seq_len` (int > 0): length of each action sequence
- `n_elites` (int, 0 to pop_size): number of top sequences carried over unchanged to the next generation
- `mut_rate` (float, 0.0 to 1.0): probability of mutating each action in a sequence
- `cross_rate` (float, 0.0 to 1.0): probability of performing crossover between two parent sequences
- `tourn_size` (int, 1 to pop_size): number of candidates in each tournament selection round
- `objectives` (map of metric name to float weight, non-empty): the genetic optimizer maximizes the weighted sum of these metrics; every metric must be in the backtest schema `metrics`
- `random_seed` (int, optional): seed for the optimizer's RNG, making the run reproducible. Omit (or set null) for a non-deterministic run

Backtest Schema:
Configuration for the backtesting simulation that evaluates strategy performance.

- `start_offset` (int >= 0): number of initial bars to skip before trading begins
- `start_balance` (float > 0.0): initial account balance
- `delay` (int >= 0): number of bars between signal generation and order execution
- `metrics` (array of metric names, non-empty): which metrics to compute and report in backtest results. Valid names: `"sharpe"`, `"excess_sharpe"`, `"max_drawdown"`, `"mean_hold_time"`, `"std_hold_time"`, `"total_entries"`, `"total_exits"`, `"signal_exits"`, `"stop_loss_exits"`, `"take_profit_exits"`, `"max_hold_exits"`

Strategy:
Configuration for the trading logic and optimization. At most one position is open at any time. When the entry node outputs true and no position is open, a position is opened; the position is closed when the exit node outputs true or any of the risk limits are hit.

- `base_net` (logic or decision network object): the starting network the optimizer applies actions to
- `feats` (array of feature objects): features available to the network
- `actions` (logic or decision actions object): action set for the optimizer; must match `base_net` type
- `penalties` (logic or decision penalties object): penalty weights subtracted from fitness; must match `base_net` type
- `stop_conds` (stop conditions object): conditions that terminate optimization
- `opt` (genetic optimizer object): optimization algorithm configuration
- `entry_ptr` (node pointer object): points to the network node whose output triggers entry
- `exit_ptr` (node pointer object): points to the network node whose output triggers exit
- `stop_loss` (float > 0.0): normalized loss threshold that triggers an exit
- `take_profit` (float > 0.0): normalized profit threshold that triggers an exit
- `max_hold_time` (int > 0): maximum number of bars to hold a position before forced exit
- `qty` (float > 0.0): absolute number of units to buy per entry

Experiment:
The top-level object that combines a strategy with cross-validation and backtesting parameters.

- `val_size` (float > 0.0, val_size + test_size < 1.0): fraction of data reserved for validation in each fold
- `test_size` (float > 0.0, val_size + test_size < 1.0): fraction of data reserved for testing in each fold
- `cv_folds` (int > 0): number of cross-validation folds
- `fold_size` (float, > 0.0 and <= 1.0): fraction of total data used per fold
- `symbol` (string, default `BTC_USDT`): which coin's OHLC to backtest on. One of: `BTC_USDT`, `ETH_USDT`, `SOL_USDT`, `BNB_USDT`, `XRP_USDT`, `ADA_USDT`, `DOGE_USDT`, `AVAX_USDT`, `LINK_USDT`, `DOT_USDT`.
- `start_timestamp` (ISO 8601 UTC string): inclusive start of the experiment data window. Example: "2024-01-01T00:00:00Z".
- `end_timestamp` (ISO 8601 UTC string): inclusive end of the experiment data window. Must be after `start_timestamp`.
- `backtest_schema` (backtest schema object): backtesting configuration
- `strategy` (strategy object): the trading strategy to optimize and evaluate

__Constraints__:
- Feature ids must be unique
- Logic penalties cannot be paired with decision networks
- Decision penalties cannot be paired with logic networks
- Fast windows must be <= slow windows
- Indicator windows must be positive integers
- Bollinger `std_multiplier` must be > 0.0
- Only OHLC data is available; do not use volume-based indicators
- Input and branch feat_id values must exist in the feature list
- Every feature must have a corresponding threshold range
- feat_order must contain every feature id exactly once
- in1/in2/true/false/ref indices must be < # of nodes
- Feature id in a threshold range object must exist
- Max > min in a threshold range object
- Meta actions cannot have other meta actions as sub actions
- Genetic `n_elites` must be <= `pop_size`; `tournament_size` must be in 1 to `pop_size`
- `val_size` + `test_size` must be < 1.0
- `stop_loss`, `take_profit`, and `qty` must be > 0.0
- `max_hold_time` must be > 0

__Notes__:
- Node pointer and node-link indices are 0-based. null means unset.
- "Normalized" means divided by the chosen `ohlc` price (or close, for indicators without an `ohlc` field — `normalized_atr`, `normalized_dc`)

# Results Description

The `experiment` object is described above. The `results` value has one of these shapes:

Successful Results:

On success, `results` is a JSON array of fold result objects, one per cross-validation fold.

Fold Result:

- `train_start_timestamp` (ISO 8601 UTC string): inclusive start timestamp of the training split
- `train_end_timestamp` (ISO 8601 UTC string): inclusive end timestamp of the training split
- `val_start_timestamp` (ISO 8601 UTC string): inclusive start timestamp of the validation split
- `val_end_timestamp` (ISO 8601 UTC string): inclusive end timestamp of the validation split
- `test_start_timestamp` (ISO 8601 UTC string): inclusive start timestamp of the test split
- `test_end_timestamp` (ISO 8601 UTC string): inclusive end timestamp of the test split
- `opt_results` (optimizer results object): optimization trace for this fold
- `train_results` (backtest results object): backtest metrics on the training split
- `val_results` (backtest results object): backtest metrics on the validation split
- `test_results` (backtest results object): backtest metrics on the test split

Optimizer Results:

- `iters` (int): number of optimizer iterations completed
- `best_train_seq` (array of strings): best action sequence by training score for the fold
- `best_train_net` (network object): network produced by applying `best_train_seq` to the base network
- `best_val_seq` (array of strings): best action sequence by validation score for the fold
- `best_val_net` (network object): network produced by applying `best_val_seq` to the base network
- `train_improvements` (array of improvement objects): new training-score highs reached during optimization
- `val_improvements` (array of improvement objects): new validation-score highs reached during optimization

Improvement Object:

- `iter` (int): optimizer iteration where the new best score was reached
- `score` (float): the new best score at that iteration

Improvement arrays may be empty. They only record iterations that set a new best score.

Backtest Results:

- `is_invalid` (bool): whether the backtest split is invalid
- `n_bars` (int): number of bars backtested after applying `start_offset`
- `equity_curve` (array of floats): the split's equity (cash + open position value) over time, downsampled to at most 100 equally spaced points
- `metrics` (object): maps each requested metric name to its float value for that split; only the metrics listed in the schema's `metrics` are present. Metric meanings:
  - `sharpe`: strategy equity Sharpe
  - `excess_sharpe`: strategy Sharpe minus benchmark close-price Sharpe
  - `max_drawdown`: largest peak-to-trough decline of the equity curve, as a fraction (0.2 = 20% drop)
  - `mean_hold_time`: mean position hold time in bars
  - `std_hold_time`: standard deviation of position hold time in bars
  - `total_entries`: number of entered positions
  - `total_exits`: total number of exited positions
  - `signal_exits`: exits triggered by the exit signal
  - `stop_loss_exits`: exits triggered by stop loss
  - `take_profit_exits`: exits triggered by take profit
  - `max_hold_exits`: exits triggered by max hold time

A backtest split is marked invalid when equity goes negative or when there are zero exits. In that case, every requested metric in `metrics` is `0.0`.

Validation Error Results:

If experiment parsing or validation fails before execution starts, `results` is a JSON object with this shape instead of an array:

`{ "error": <string>, "is_internal": false }`

`query_experiments` queries this JSON structure directly using dot-paths and array aggregates.

# Notebook Description

A notebook is a list of tiles displayed top to bottom in order, where each tile is a query paired with an accompanying note. `queries` is an ordered list of query objects, each with a single `query` field holding a raw, SQL-style query string. `notes` is a list of note strings aligned by index with `queries`; `notes[i]` is the note for `queries[i]`, so both lists must have the same length. `title` is a short human-readable label for the submission. Query `results` are populated server-side.

__Before creating/modifying notebook queries, you should first run those queries using `query_experiments`__

Notebook Query Results Object:
```
{
    "path": str,
    "values": [array],
    "ids": [array of int],
    "skipped": int >= 0
}
```

Notebook Query Object:
```
{
    "query": str,
    "results": null or [array of notebook query results objects]
}
```

Notebook Object:
```
{
    "title": str,
    "queries": [array of notebook query objects],
    "notes": [array of str],
    "status": "idle" or "working" or "errored",
    "error_message": str or null
}
```

Newlines and indentation are significant in the query. Example:

    select:
        title
        results.mean:test_results.metrics.excess_sharpe
    filters:
        results.mean:test_results.metrics.excess_sharpe > 0
    limit: 10
    offset: 0

`select:` lists one path per indented line (required, at least one). Paths use dot notation over the experiment and results objects, include `title` and `last_updated`, and support per-fold aggregates with `<array_path>.<func>:<inner_path>` syntax for len, mean, std, min, and max, e.g. "experiment.strategy.stop_loss" or "results.mean:test_results.metrics.excess_sharpe". Aggregates can be nested, e.g. "results.mean:test_results.std:equity_curve.self". End an aggregate's inner path with `.self` to aggregate the elements of a leaf list (e.g. `equity_curve`) directly instead of indexing a dict key. `id` cannot be selected or filtered; each returned value is annotated with its experiment id in parentheses, e.g. `0.42 (100)`. ISO-8601 timestamp values are shown as `Jan 2 2026 12:00`. `filters:` lists one `path <op> value` per indented line (optional; all must match). Operators: >=, >, <=, <, == ; values are numbers, ISO timestamps like `2024-06-01T00:00:00` or `2024-06-01T00:00:00Z`, "quoted strings", or true/false. `limit: N` caps the number of experiments (optional, default 25, max 25). `offset: N` skips N matching experiments before applying limit (optional, default 0). Each query returns the raw selected values per path.

"""

EXPERIMENT_SCHEMA = """\
# Experiment source format

To submit an experiment, you author one experiment as indentation-based source text (the `source` command parameter) describing a concrete trading strategy and its evaluation setup. The runner parses it, fills defaults, validates it, and executes it. Each submission queues a single experiment. The field meanings and constraints are in the Experiment Description above; this section defines the text shape.

__Format rules__:
- Two spaces per indentation level. `key: value` for a scalar; `key:` alone on a line followed by deeper-indented lines for a nested object.
- Strings are bare, no quotes (`ohlc: close`). Booleans are `true`/`false`. An unset optional value is `null`.
- Scalar lists are inline and comma-separated on one line: `metrics: excess_sharpe, sharpe`.
- Collections of objects are written as keyed maps, not arrays. Each item is a key line followed by its indented fields:
  - `feats:` items are keyed by feature id (the id is the key, not a field inside).
  - `nodes:` items are keyed by 0-based index (`0:`, `1:`, ...) in evaluation order.
  - `thresholds:` items are keyed by feat_id.
  - `meta_actions:` items are keyed by label, each holding a `sub_actions:` inline list.
- Any omitted field uses a sensible default; an entirely omitted object uses default parameters. Example defaults: `val_size` 0.2, `test_size` 0.2, `cv_folds` 5, `end_timestamp` today.
- `start_timestamp`/`end_timestamp` accept ISO 8601, e.g. `2024-01-01T00:00:00Z`.
- Aliases: `backtest_schema` may be written `bt_schema` or `backtest`; `std_multiplier` may be written `std_mult`.

__Strategy Type__:

The runner selects the strategy parser from `strategy.base_net.type` ("logic" or "decision"). `base_net` carries `type` plus the active network fields directly; `actions` and `penalties` must be the matching logic or decision shape. Do not add inactive sibling objects or any extra wrapper around these fields.

## Feature (one entry under `feats:`, keyed by its unique id)

```
<feature id>:
  feature: constant
  constant: float
```
OR
```
<feature id>:
  feature: raw_returns
  returns_type: log or simple
  ohlc: open, high, low, or close
```
OR
```
<feature id>:
  feature: normalized_sma
  window: int > 0
  ohlc: open, high, low, or close
```
OR
```
<feature id>:
  feature: normalized_ema
  window: int > 0
  smooth: int > 0
  ohlc: open, high, low, or close
```
OR
```
<feature id>:
  feature: normalized_macd
  fast_window: int > 0
  fast_smooth: int > 0
  slow_window: int > 0
  slow_smooth: int > 0
  signal_window: int > 0
  signal_smooth: int > 0
  ohlc: open, high, low, or close
  output: line, signal, or hist
```
OR
```
<feature id>:
  feature: rsi
  window: int > 0
  smooth: int > 0
  ohlc: open, high, low, or close
```
OR
```
<feature id>:
  feature: normalized_bb
  ohlc: open, high, low, or close
  window: int > 0
  std_multiplier: float > 0.0
  output: upper, lower, or width
```
OR
```
<feature id>:
  feature: stochastic
  window: int > 0
  smooth_window: int > 0
  output: percent_k or percent_d
```
OR
```
<feature id>:
  feature: normalized_atr
  window: int > 0
  smooth: int > 0
```
OR
```
<feature id>:
  feature: roc
  window: int > 0
  ohlc: open, high, low, or close
```
OR
```
<feature id>:
  feature: normalized_dc
  window: int > 0
  output: upper, lower, middle, or width
```

## Node Pointer
```
anchor: from_start or from_end
offset: int >= 0
```

## Logic Node (one entry under `nodes:`, keyed by 0-based index)
```
<index>:
  type: input
  threshold: float or null
  feat_id: str or null
```
OR
```
<index>:
  type: gate
  gate: and, or, xor, nand, nor, xnor, or null
  in1_idx: int or null
  in2_idx: int or null
```

## Decision Node (one entry under `nodes:`, keyed by 0-based index)
```
<index>:
  type: branch
  threshold: float or null
  feat_id: str or null
  true_idx: int or null
  false_idx: int or null
```
OR
```
<index>:
  type: ref
  ref_idx: int or null
  true_idx: int or null
  false_idx: int or null
```

## Network (the `base_net:` object)
```
type: logic
nodes:
  <index>:
    <logic nodes>
default_value: bool
```
OR
```
type: decision
nodes:
  <index>:
    <decision nodes>
default_value: bool
max_trail_len: int > 0
```

## Penalties (the `penalties:` object)
```
type: logic
node: float >= 0.0
input: float >= 0.0
gate: float >= 0.0
recurrence: float >= 0.0
feedforward: float >= 0.0
used_feat: float >= 0.0
unused_feat: float >= 0.0
```
OR
```
type: decision
node: float >= 0.0
branch: float >= 0.0
ref: float >= 0.0
leaf: float >= 0.0
non_leaf: float >= 0.0
used_feat: float >= 0.0
unused_feat: float >= 0.0
```

## Threshold (one entry under `thresholds:`, keyed by feat_id)
```
<feat_id>:
  min: float
  max: float
```

## Meta Action
```
<label>:
  sub_actions: action1, action2, ...
```

## Actions
```
type: logic
thresholds:
  <feat_id>:
    min: float
    max: float
feat_order: id1, id2, ...
n_thresholds: int > 0
allow_recurrence: bool
allowed_gates: and, or, xor
```
OR
```
type: decision
meta_action:
  <list of meta action objects>
thresholds:
  <feat_id>:
    min: float
    max: float
feat_order: id1, id2, ...
n_thresholds: int > 0
allow_refs: bool
```

## Stop Conditions (the `stop_conds:` object)
```
max_iters: int > 0
train_patience: int >= 0
val_patience: int >= 0
```

## Optimizer (the `opt:` object)
```
type: genetic
pop_size: int > 0
seq_len: int > 0
n_elites: int
mut_rate: 0.0 <= float <= 1.0
cross_rate: 0.0 <= float <= 1.0
tourn_size: int
objectives:
  <metric name>: <float weight>
  ...
random_seed: <int, optional — omit for a non-deterministic run>
```

## Backtest Schema (the `backtest_schema:` object)
```
start_offset: int >= 0
start_balance: float > 0.0
delay: int >= 0
metrics: <non-empty inline list of metric names: sharpe, excess_sharpe, max_drawdown, mean_hold_time, std_hold_time, total_entries, total_exits, signal_exits, stop_loss_exits, take_profit_exits, max_hold_exits>
```

## Strategy (the `strategy:` object)
```
base_net:
  <logic or decision network>
feats:
  <feature entries>
actions:
  <matching logic or decision actions>
penalties:
  <matching logic or decision penalties>
stop_conds:
  <stop conditions>
opt:
  <optimizer>
entry_ptr:
  <node pointer>
exit_ptr:
  <node pointer>
stop_loss: float > 0.0
take_profit: float > 0.0
max_hold_time: int > 0
qty: float > 0.0
```

## Experiment (top level)
```
val_size: float > 0.0
test_size: float > 0.0
cv_folds: int > 0
fold_size: 0.0 < float <= 1.0
symbol: string (exchange pair, e.g. BTC_USDT; default BTC_USDT)
start_timestamp: ISO 8601 UTC string
end_timestamp: ISO 8601 UTC string
backtest_schema:
  <backtest schema>
strategy:
  <strategy>
```

## Complete example

```
val_size: 0.2
test_size: 0.2
cv_folds: 3
fold_size: 0.7
symbol: BTC_USDT
start_timestamp: 2024-01-01T00:00:00Z
end_timestamp: 2024-07-01T00:00:00Z
backtest_schema:
  start_offset: 80
  start_balance: 10000.0
  delay: 1
  metrics: excess_sharpe, sharpe, total_entries, total_exits, mean_hold_time
strategy:
  base_net:
    type: logic
    nodes:
      0:
        type: input
        threshold: 0.0
        feat_id: close_log_ret
      1:
        type: input
        threshold: 1.0
        feat_id: ema_21_norm
      2:
        type: gate
        gate: and
        in1_idx: 0
        in2_idx: 1
      3:
        type: input
        threshold: 70.0
        feat_id: rsi_14
    default_value: false
  feats:
    close_log_ret:
      feature: raw_returns
      returns_type: log
      ohlc: close
    sma_50_norm:
      feature: normalized_sma
      window: 50
      ohlc: close
    ema_21_norm:
      feature: normalized_ema
      window: 21
      smooth: 2
      ohlc: close
    rsi_14:
      feature: rsi
      window: 14
      smooth: 2
      ohlc: close
  actions:
    type: logic
    thresholds:
      close_log_ret:
        min: -0.03
        max: 0.03
      sma_50_norm:
        min: 0.95
        max: 1.05
      ema_21_norm:
        min: 0.95
        max: 1.05
      rsi_14:
        min: 25.0
        max: 75.0
    feat_order: close_log_ret, sma_50_norm, ema_21_norm, rsi_14
    n_thresholds: 9
    allow_recurrence: false
    allowed_gates: and, or, xor
  penalties:
    type: logic
    node: 0.001
    input: 0.001
    gate: 0.001
    recurrence: 0.01
    feedforward: 0.0
    used_feat: 0.001
    unused_feat: 0.0
  stop_conds:
    max_iters: 6
    train_patience: 3
    val_patience: 3
  opt:
    type: genetic
    pop_size: 12
    seq_len: 8
    n_elites: 2
    mut_rate: 0.1
    cross_rate: 0.7
    tourn_size: 3
    objectives:
      excess_sharpe: 0.7
      sharpe: 0.3
    random_seed: 42
  entry_ptr:
    anchor: from_start
    offset: 2
  exit_ptr:
    anchor: from_start
    offset: 3
  stop_loss: 0.04
  take_profit: 0.08
  max_hold_time: 72
  qty: 0.01
```"""

TAIL = """

# Additional Instructions

[ADDITIONAL_INSTRUCTIONS]

# Summary of past interaction

[SUMMARY]

# User prompt

[PROMPT]

# Response

Your response to this prompt must be a Response JSON Object."""

MULTI_ENV_HEADER = """\
# Environment description

Global vs Personal Output:
- Global Output can be seen by all agents
- Personal Output can only be seen by you"""

SUBAGENT_DOC = """\
Command: `subagent`
Parameters: `prompt`, `n_agents`
Function: Spins up a sub-agent system with `n_agents` to perform `prompt`. The sub-agent system will run until it submits a report. The report will be returned to you."""

SUBAGENT_SCHEMA = """\
{
    "command": "subagent",
    "prompt": str,
    "n_agents": int
}"""

EXPERIMENT_DOC_TEMPLATE = """\
Command: `[CMD]`
Parameters: `title`, `source`
Function: [VERB] an experiment for execution. `title` is a short human-readable label for the submission. `source` is the experiment authored as source text following the experiment source format."""

EXPERIMENT_SCHEMA_TEMPLATE = """\
{
    "command": "[CMD]",
    "title": str,
    "source": str
}"""

NOTEBOOK_DOC_TEMPLATE = """\
Command: `[CMD]`
Parameters: `title`, `queries`, `notes`
Function: [VERB] a notebook to the user. `title` is a short human-readable label. `queries` and `notes` must follow the notebook description above."""

NOTEBOOK_SCHEMA_TEMPLATE = """\
{
    "command": "[CMD]",
    "title": str,
    "queries": [
        {
            "query": str
        }
    ],
    "notes": [str]
}"""

REPORT_DOC_TEMPLATE = """\
Command: `[CMD]`
Parameters: `title`, `report`
Function: [VERB] a report containing `report` to be sent to the main agent. `title` is a short human-readable label for the submission."""

REPORT_SCHEMA_TEMPLATE = """\
{
    "command": "[CMD]",
    "title": str,
    "report": str
}"""

MULTI_COMMAND_DOCS = """\
Command: `vote`
Parameters: None
Function: Increments the number of votes for the proposal.

Command: `message`
Parameters: `content`
Function: Sends a message containing `content` to your fellow AIs."""

MULTI_COMMAND_SCHEMAS = """\
{
    "command": "vote"
}

OR

{
    "command": "message",
    "content": str
}"""

SHARED_COMMAND_DOCS = """\
Command: `query_experiments`
Parameters: `query`
Function: Runs a raw, SQL-style query string against completed experiments and returns the raw selected values per path. Experiments with missing keys are skipped automatically.

The query string is line-oriented; newlines and indentation are significant:

    select:
        title
        results.mean:test_results.metrics.excess_sharpe
    filters:
        results.mean:test_results.metrics.excess_sharpe > 0
    limit: 10
    offset: 0

- `select:` lists one dot-path per indented line (required, at least one)
- Paths use dot notation over the experiment and results objects, include `title` and `last_updated`, and support per-fold aggregates with `<array_path>.<func>:<inner_path>` syntax for len, mean, std, min, and max: "results.mean:test_results.metrics.excess_sharpe" computes the mean across the fold result array. Aggregates can be nested, e.g. "results.mean:test_results.std:equity_curve.self". End an aggregate's inner path with `.self` to aggregate the elements of a leaf list (e.g. `equity_curve`) directly instead of indexing a dict key
- `id` cannot be selected or filtered; each returned value is annotated with its experiment id in parentheses, e.g. `0.42 (100)`. ISO-8601 timestamp values are shown as `Jan 2 2026 12:00`
- `filters:` lists one `path <op> value` per indented line (optional; all must match). Operators: >=, >, <=, <, == ; values are numbers, ISO timestamps like `2024-06-01T00:00:00` or `2024-06-01T00:00:00Z`, "quoted strings", or true/false
- `limit: N` caps the number of experiments (optional, default 25, max 25)
- `offset: N` skips N matching experiments before applying limit (optional, default 0)"""

SHARED_COMMAND_SCHEMAS = """\
{
    "command": "query_experiments",
    "query": str
}"""

RESPONSE_SCHEMA = """\
Response Object:

{
    "thought": str,
    "commands": [array of command objects]
}"""


def replace_tokens(text: str, replacements: dict[str, str]) -> str:
    result = text

    for old, new in replacements.items():
        result = result.replace(old, new)

    return result


def build_profile(is_multi: bool, is_subagent: bool) -> str:
    directive = "You, [AGENT_ID], are an expert AI quantitative researcher whose directive is to"

    if is_multi:
        directive += " collaborate with other AI agents, [OTHER_AGENTS], to"

    if is_subagent:
        directive += " complete a task delegated by another AI agent and write a report detailing your findings."
    else:
        directive += " build the best possible trading strategies."

    directive += " Here are the competencies you possess:"

    competencies = MULTI_COMPETENCIES if is_multi else SINGLE_COMPETENCIES
    return f"# Profile\n{directive}\n\n{competencies}"

def voting_description_for_mode(mode: str) -> str:
    if mode == "report":
        action = "submit a report to the main agent"
        subject = "the report"
        trigger = "a report is proposed"
        outcome = "the report will be submitted to the main agent"
    elif mode == "notebook":
        action = "submit a notebook to the user"
        subject = "the notebook"
        trigger = "a notebook is proposed"
        outcome = "the notebook will be submitted to the user"
    else:
        action = "run an experiment"
        subject = "an experiment"
        trigger = "the experiment is proposed"
        outcome = "the submission will be sent for human approval"

    return f"""\
- To {action}, you first must propose {subject}
- Once {trigger}, voting begins immediately
- If the majority of agents vote in favor of the proposal, {outcome}"""


def voting_description(is_subagent: bool) -> str:
    mode_sections = [voting_description_for_mode(mode) for mode in (["report"] if is_subagent else ["experiment", "notebook"])]
    mode_text = "\n".join(mode_sections)

    return f"""\
Proposals and Voting
{mode_text}
- If you think the proposal should be submitted, cast your vote
- If you don't think the proposal should be submitted, abstain from voting
- You should make your voting decision immediately after a proposal, but not while making the proposal itself.
- You automatically vote for your own proposal"""

def build_env(is_multi: bool, is_subagent: bool) -> str:
    parts = []

    if is_multi:
        voting = voting_description(is_subagent)
        parts.append(f"{MULTI_ENV_HEADER}\n\n{voting}")
        parts.append("# Commands\nUse commands to interact with the environment and communicate with your fellow agents.")
    else:
        parts.append("# Commands\nUse commands to interact with the environment.")

    cmd_docs = []
    cmd_schemas = []

    if not is_subagent:
        cmd_docs.append(SUBAGENT_DOC)
        cmd_schemas.append(SUBAGENT_SCHEMA)

    if is_multi:
        verb = "Proposes"
        cmd_prefix = "propose"
    else:
        verb = "Submits"
        cmd_prefix = "submit"

    modes = ["report"] if is_subagent else ["experiment", "notebook"]

    for mode in modes:
        if mode == "experiment":
            cmd_name = f"{cmd_prefix}_experiment"
            doc_template = EXPERIMENT_DOC_TEMPLATE
            schema_template = EXPERIMENT_SCHEMA_TEMPLATE
        elif mode == "notebook":
            cmd_name = f"{cmd_prefix}_notebook"
            doc_template = NOTEBOOK_DOC_TEMPLATE
            schema_template = NOTEBOOK_SCHEMA_TEMPLATE
        else:
            cmd_name = f"{cmd_prefix}_report"
            doc_template = REPORT_DOC_TEMPLATE
            schema_template = REPORT_SCHEMA_TEMPLATE

        variant_doc = replace_tokens(doc_template, {"[CMD]": cmd_name, "[VERB]": verb})
        cmd_docs.append(variant_doc)

        variant_schema = replace_tokens(schema_template, {"[CMD]": cmd_name, "[VERB]": verb})
        cmd_schemas.append(variant_schema)

    if is_multi:
        cmd_docs.append(MULTI_COMMAND_DOCS)
        cmd_schemas.append(MULTI_COMMAND_SCHEMAS)

    cmd_docs.append(SHARED_COMMAND_DOCS)
    cmd_schemas.append(SHARED_COMMAND_SCHEMAS)

    cmd_docs_joined = "\n\n".join(cmd_docs)
    parts.append(cmd_docs_joined)

    schema_section = "# JSON schema\n\nCommand Object:\n\n"
    schema_section += "\n\nOR\n\n".join(cmd_schemas)
    schema_section += "\n\n" + RESPONSE_SCHEMA
    parts.append(schema_section)

    return "\n\n".join(parts)


def make_system_prompt(state: AgentsState, additional_instructions: str) -> str:
    agent_ids = state["agent_order"]
    curr_agent_id = get_agent_id(state)
    is_subagent = state["is_subagent"]

    is_multi = len(agent_ids) > 1

    parts = [build_profile(is_multi, is_subagent)]
    parts.append(EXPERIMENT_RESULTS_NOTEBOOK_DESCRIPTION)

    if not is_subagent:
        parts.append(EXPERIMENT_SCHEMA)

    env_part = build_env(is_multi, is_subagent)
    parts.append(env_part)
    parts.append(TAIL)

    prompt = "\n\n".join(parts)

    other_agents = ", ".join([agent_id for agent_id in agent_ids if agent_id != curr_agent_id])

    prompt = prompt.replace("[OTHER_AGENTS]", other_agents)
    prompt = prompt.replace("[AGENT_ID]", curr_agent_id)
    prompt = prompt.replace("[ADDITIONAL_INSTRUCTIONS]", additional_instructions)
    prompt = prompt.replace("[SUMMARY]", state["summaries"][curr_agent_id])
    prompt = prompt.replace("[PROMPT]", state["user_prompt"])

    return prompt
