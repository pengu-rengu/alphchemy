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

EXPERIMENT_ONTOLOGY = """\
# Experiment Description

An Experiment defines a trading strategy and evaluates it via cross-validated backtesting. The strategy uses a boolean network to generate entry/exit signals from numerical features. A genetic algorithm optimizes the network structure by applying sequences of actions to a base network, maximizing excess Sharpe ratio (strategy Sharpe minus benchmark Sharpe) on training data while validating on held-out data.

Constant Feature:
A feature that outputs the same fixed value for every bar.

- `id` (unique string): identifier for this feature
- `constant` (float): the value to output

Raw Returns Feature:
A feature that computes bar-to-bar price returns from OHLC data.

- `id` (unique string): identifier for this feature
- `returns_type` ("log" or "simple"): log returns use ln(price[i] / price[i-1]), simple returns use (price[i] / price[i-1]) - 1
- `ohlc` ("open", "high", "low", or "close"): which price series to compute returns from

Node Pointer:
A reference to a node in a network, resolved to an absolute index at runtime.

- `anchor` ("from_start" or "from_end"): whether the index counts from the beginning or end of the node list
- `idx` (int >= 0): offset from the anchor

Logic Input Node:
A node that compares a feature value to a threshold, outputting true if the feature value exceeds the threshold.

- `threshold` (float or null): comparison threshold. null means unset, and the node outputs the network default value
- `feat_idx` (int or null, < number of features): index into the feature list. null means unset

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
- `feat_idx` (int or null, < number of features): index into the feature list. null means unset
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
- `n_thresholds` (int > 0): number of discrete threshold levels per feature range
- `allow_recurrence` (bool): whether gate nodes can reference nodes at the same or higher index
- `allowed_gates` (array of gate strings): which gate types the optimizer can assign

Decision Actions:
Configuration for the set of actions available to the genetic algorithm when optimizing a decision network.

- `meta_actions` (array of meta action objects): composite actions available to the optimizer
- `thresholds` (array of threshold range objects, one per feature): threshold ranges for each feature
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
- `tournament_size` (int, 1 to pop_size): number of candidates in each tournament selection round

Entry Schema:
Defines a condition for entering a trade position. When the referenced node outputs true, a position is opened.

- `node_ptr` (node pointer object): points to the network node whose output triggers entry
- `position_size` (float, > 0.0 and <= 1.0): fraction of current balance to allocate to each position
- `max_positions` (int > 0): maximum number of concurrent open positions for this entry

Exit Schema:
Defines conditions for closing open positions. A position is closed when the exit signal fires or any of the risk limits are hit.

- `node_ptr` (node pointer object): points to the network node whose output triggers exit
- `entry_indices` (array of int, non-empty, each < length of entry_schemas): which entry schemas this exit applies to
- `stop_loss` (float > 0.0): normalized loss threshold that triggers an exit
- `take_profit` (float > 0.0): normalized profit threshold that triggers an exit
- `max_hold_time` (int > 0): maximum number of bars to hold a position before forced exit

Backtest Schema:
Configuration for the backtesting simulation that evaluates strategy performance.

- `start_offset` (int >= 0): number of initial bars to skip before trading begins
- `start_balance` (float > 0.0): initial account balance
- `delay` (int >= 0): number of bars between signal generation and order execution

Experiment:
The top-level object that combines a strategy with cross-validation and backtesting parameters.

- `val_size` (float > 0.0, val_size + test_size < 1.0): fraction of data reserved for validation in each fold
- `test_size` (float > 0.0, val_size + test_size < 1.0): fraction of data reserved for testing in each fold
- `cv_folds` (int > 0): number of cross-validation folds
- `fold_size` (float, > 0.0 and <= 1.0): fraction of total data used per fold
- `backtest_schema` (backtest schema object): backtesting configuration
- `strategy` (strategy object): the trading strategy to optimize and evaluate

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

# Ontology description

- The Ontology is an abstraction of raw experiments and results data. The Ontology consists of Hypotheses, which are claims on whether experiments that satisfy a given set of conditions have a higher value of a given result metric than experiments that do not satisfy the conditions.
- Hypotheses are related to each other based on whether they validate/invalidate each other.
- If two hypotheses agree on whether the experiments that satisfy their conditions have a higher value of a given result metric than experiments that do not, and then jaccard similarity between experiments of the two hypotheses is sufficient, then the hypotheses validate each other.
- Otherwise the two hypothesis invalidate each other."""

EXPERIMENT_GENERATOR = """\
# Experiment Generator Description

To submit experiments, you provide a generator config and a search space. The system generates experiments by substituting all combinations of search space values into the generator template.

__Param Key Object__:

Any field that should vary across experiments uses a Param Key: `{"key": "param_name"}`. The corresponding key in the search space maps to a list of possible values. All combinations are generated via cartesian product, capped at 1000 experiments.

For example, if the search space is `{"x": [1, 2], "y": [true, false]}`, then 4 experiments are generated: (x=1, y=true), (x=1, y=false), (x=2, y=true), (x=2, y=false).

__Pools__:

Pools let you define a set of items and select a subset by index. The generator has 6 pool mappings:

- `feat_pool` + `feat_selection` -> `feats`
- `node_pool` + `node_selection` -> `nodes`
- `entry_pool` + `entry_selection` -> `entry_schemas`
- `exit_pool` + `exit_selection` -> `exit_schemas`
- `meta_action_pool` + `meta_action_selection` -> `meta_actions`
- `threshold_pool` + `threshold_selection` -> `thresholds`

The pool field is a list of items. The selection field is a list of 0-based indices, or a Param Key resolving to one. During generation, the selected indices pick items from the pool.

__Merge Fields__:

`NetworkGen`, `ActionsGen`, and `PenaltiesGen` each have a `type` field and paired sub-objects. During generation, only the sub-object whose name starts with the `type` value is kept, and its fields are merged into the parent object. The other sub-object is discarded.

Both sub-objects must always be present in the generator. Set the unused one to `null` if the type is fixed. If the type varies via a Param Key, both must be fully defined.

# Experiment Generator JSON schema

Param Key Object:
```
{"key": str}
```

Feature Object:

```
{
    "feature": "constant",
    "id": str or param key,
    "constant": float or param key
}
```

OR

```
{
    "feature": "raw_returns",
    "id": str or param key,
    "returns_type": str or param key,
    "ohlc": str or param key
}
```

Node Pointer Object:
```
{
    "anchor": str or param key,
    "idx": int or param key
}
```

Logic Node Object:

```
{
    "type": "input",
    "threshold": null or float or param key,
    "feat_idx": null or int or param key
}
```

OR

```
{
    "type": "gate",
    "gate": str or param key or null,
    "in1_idx": int or param key or null,
    "in2_idx": int or param key or null
}
```

Decision Node Object:

```
{
    "type": "branch",
    "threshold": float or param key or null,
    "feat_idx": int or param key or null,
    "true_idx": int or param key or null,
    "false_idx": int or param key or null
}
```

OR

```
{
    "type": "ref",
    "ref_idx": int or param key or null,
    "true_idx": int or param key or null,
    "false_idx": int or param key or null
}
```

Logic Network Object:
```
{
    "node_pool": [array of logic node objects],
    "node_selection": [array of int] or param key,
    "default_value": bool or param key
}
```

Decision Network Object:
```
{
    "node_pool": [array of decision node objects],
    "node_selection": [array of int] or param key,
    "default_value": bool or param key,
    "max_trail_len": int or param key
}
```

Network Object (merge field: type determines which sub-object is kept):
```
{
    "type": str or param key,
    "logic_net": logic network object or null,
    "decision_net": decision network object or null
}
```

Logic Penalties Object:
```
{
    "node": float or param key,
    "input": float or param key,
    "gate": float or param key,
    "recurrence": float or param key,
    "feedforward": float or param key,
    "used_feat": float or param key,
    "unused_feat": float or param key
}
```

Decision Penalties Object:
```
{
    "node": float or param key,
    "branch": float or param key,
    "ref": float or param key,
    "leaf": float or param key,
    "non_leaf": float or param key,
    "used_feat": float or param key,
    "unused_feat": float or param key
}
```

Penalties Object (merge field):
```
{
    "type": str or param key,
    "logic_penalties": logic penalties object or null,
    "decision_penalties": decision penalties object or null
}
```

Threshold Range Object:
```
{
    "feat_id": str or param key,
    "min": float or param key,
    "max": float or param key
}
```

Meta Action Object:
```
{
    "label": str or param key,
    "sub_actions": list or param key
}
```

Logic Actions Object:
```
{
    "meta_action_pool": [array of meta action objects],
    "meta_action_selection": [array of int] or param key,
    "threshold_pool": [array of threshold range objects],
    "threshold_selection": [array of int] or param key,
    "n_thresholds": int or param key,
    "allow_recurrence": bool or param key,
    "allowed_gates": list or param key
}
```

Decision Actions Object:
```
{
    "meta_action_pool": [array of meta action objects],
    "meta_action_selection": [array of int] or param key,
    "threshold_pool": [array of threshold range objects],
    "threshold_selection": [array of int] or param key,
    "n_thresholds": int or param key,
    "allow_refs": bool or param key
}
```

Actions Object (merge field):
```
{
    "type": str or param key,
    "logic_actions": logic actions object or null,
    "decision_actions": decision actions object or null
}
```

Stop Conditions Object:
```
{
    "max_iters": int or param key,
    "train_patience": int or param key,
    "val_patience": int or param key
}
```

Optimizer Object:
```
{
    "type": "genetic",
    "pop_size": int or param key,
    "seq_len": int or param key,
    "n_elites": int or param key,
    "mut_rate": float or param key,
    "cross_rate": float or param key,
    "tournament_size": int or param key
}
```

Entry Schema Object:
```
{
    "node_ptr": node pointer object,
    "position_size": float or param key,
    "max_positions": int or param key
}
```

Exit Schema Object:
```
{
    "node_ptr": node pointer object,
    "entry_indices": list or param key,
    "stop_loss": float or param key,
    "take_profit": float or param key,
    "max_hold_time": int or param key
}
```

Backtest Schema Object:
```
{
    "start_offset": int or param key,
    "start_balance": float or param key,
    "delay": int or param key
}
```

Strategy Object:
```
{
    "base_net": network object,
    "feat_pool": [array of feature objects],
    "feat_selection": [array of int] or param key,
    "actions": actions object,
    "penalties": penalties object,
    "stop_conds": stop conditions object,
    "opt": optimizer object,
    "entry_pool": [array of entry schema objects],
    "entry_selection": [array of int] or param key,
    "exit_pool": [array of exit schema objects],
    "exit_selection": [array of int] or param key
}
```

Experiment Generator Object (top level):
```
{
    "title": str or param key,
    "val_size": float or param key,
    "test_size": float or param key,
    "cv_folds": int or param key,
    "fold_size": float or param key,
    "backtest_schema": backtest schema object,
    "strategy": strategy object
}
```

# Search Space JSON schema

The search space is a JSON object where each key is a string referenced by Param Key objects, and each value is a list of possible values. Each of the values in the list assigned to eac key must match the type in the field in generator schema where the key is used.

```
{
    "param_name_1": [value1, value2],
    "param_name_2": [value3, value4, value5],
    etc..
}
```"""

TAIL = """\
# Summary of past interaction

[SUMMARY]

# Response

Your response to this prompt must be a Response JSON Object."""

MULTI_ENV_HEADER = """\
# Environment description

Global vs Personal Output:
- Global Output can be seen by all agents
- Personal Output can only be seen by you"""

SUBAGENT_DOC = """\
Command: `subagent`
Parameters: `task`, `n_agents`
Function: Spins up a sub-agent system with `n_agents` to perform `task`. The sub-agent system will run until it submits a report. The report will be returned to you."""

SUBAGENT_SCHEMA = """\
{
    "command": "subagent",
    "task": str,
    "n_agents": int
}"""

EXPERIMENTS_DOC_TEMPLATE = """\
Command: `[CMD]`
Parameters: `generator`, `search_space`
Function: [VERB] a generator schema and search space to generate experiments. Properties of the generator schema can either be a constant, or a referenece to a parameter in the search space. Up to 1000 experiments are generated from the cartesian product."""

EXPERIMENTS_SCHEMA_TEMPLATE = """\
{
    "command": "[CMD]",
    "generator": Experiment Generator object,
    "search_space": {string: [array of values]}
}"""

REPORT_DOC_TEMPLATE = """\
Command: `[CMD]`
Parameters: `content`
Function: [VERB] a report containing `content` to be sent back to the main agent."""

REPORT_SCHEMA_TEMPLATE = """\
{
    "command": "[CMD]",
    "content": str
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
Command: `traverse`
Parameters: `hyp_id`, `algorithm`, `max_count`
Function: Ouputs no more than `max_count` hypotheses from a traversal of the Ontology, starting with the Hypothesis with `hyp_id`. If `hyp_id` is set to -1, the traversal starts at a random Hypothesis.

Command: `example`
Parameters: `hyp_id`
Function: Outputs a random experiment that satisfies the conditions of the Hypothesis with id `hyp_id`.

Command: `analyze_data`
Parameters: `column`, `filters`
Function: Parses `../data/experiments.jsonl` into one flat dataframe row per experiment, where every parsed column is a float. It applies all filters, then outputs the 5-number summary plus mean and std of `column`. Filter and target columns must use parsed row names such as `val_size`, `logic_net`, `position_size_mean`, `opt_iters_max`, `test_excess_sharpe_mean`, or `train_invalid_frac`. Indicator columns such as `logic_net` use `1.0` and `0.0`. Do not use unparsed fields like `title`."""

SHARED_COMMAND_SCHEMAS = """\
{
    "command": "traverse",
    "hyp_id": int,
    "algorithm": one of "bfs", "dfs",
    "max_count": int 1 - 10
}

OR

{
    "command": "example",
    "hyp_id": int,
}

OR

{
    "command": "analyze_data",
    "column": str,
    "filters": [
        {
            "column": str,
            "equals": int or float
        }
        OR
        {
            "column": str,
            "min_value": int or float,
            "max_value": int or float
        }
    ]
}"""

RESPONSE_SCHEMA = """\
Response Object:

{
    "thought": str,
    "commands": [array of command objects]
}"""


def build_profile(is_multi: bool, is_sub: bool) -> str:
    directive = "You, [AGENT_ID], are an expert AI quantitative researcher whose directive is to"

    if is_multi:
        directive += " collaborate with other AI agents, [OTHER_AGENTS], to"

    if is_sub:
        directive += " perform a task delegated to you by another AI agent, and to write a report detailing your findings."
    else:
        directive += " build the best possible trading strategies."
    
    directive += ". Here are the competencies you possess:"

    competencies = MULTI_COMPETENCIES if is_multi else SINGLE_COMPETENCIES
    profile = f"# Profile\n{directive}\n\n{competencies}"

    if is_sub:
        profile += "\n\n# Task\n\n[TASK]"

    return profile

def fill_template(template: str, cmd: str, verb: str) -> str:
    result = template.replace("[CMD]", cmd)
    return result.replace("[VERB]", verb)


def voting_description(is_sub: bool) -> str:
    if is_sub:
        action = "submit a report to the main agent"
        subject = "the report"
        trigger = "a report is proposed"
        approve = "the report should be submitted"
        outcome = "the report will be submitted to the main agent"
    else:
        action = "run experiments"
        subject = "experiment generator schema and a search space"
        trigger = "experiment generation code is proposed"
        approve = "the experiments should be run"
        outcome = "the generated experiments will run"

    return f"""\
Proposals and Voting
- To {action}, you first must propose {subject}
- Once {trigger}, voting begins immediately
- If you think {approve}, cast your vote
- If you don't think {approve}, abstain from voting
- You should make your voting decision immediately after a proposal, but not while making the proposal itself.
- If the majority of agents vote in favor of the proposal, {outcome}
- You automatically vote for your own proposal"""

def build_env(is_multi: bool, is_sub: bool) -> str:
    parts = []

    if is_multi:
        voting = voting_description(is_sub)
        parts.append(f"{MULTI_ENV_HEADER}\n\n{voting}")
        parts.append("# Commands\nUse commands to interact with the environment and communicate with your fellow agents.")
    else:
        parts.append("# Commands\nUse commands to interact with the environment.")

    cmd_docs = []
    cmd_schemas = []

    if not is_sub:
        cmd_docs.append(SUBAGENT_DOC)
        cmd_schemas.append(SUBAGENT_SCHEMA)

    if is_multi:
        verb = "Proposes"
        cmd_prefix = "propose"
    else:
        verb = "Submits"
        cmd_prefix = "submit"

    if is_sub:
        cmd_name = f"{cmd_prefix}_report"
        doc_template = REPORT_DOC_TEMPLATE
        schema_template = REPORT_SCHEMA_TEMPLATE
    else:
        cmd_name = f"{cmd_prefix}_experiments"
        doc_template = EXPERIMENTS_DOC_TEMPLATE
        schema_template = EXPERIMENTS_SCHEMA_TEMPLATE

    variant_doc = fill_template(doc_template, cmd_name, verb)
    cmd_docs.append(variant_doc)
    
    variant_schema = fill_template(schema_template, cmd_name, verb)
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


def make_agent_prompt(agent_ids: list[str], curr_agent_id: str, summary: str, subagent_task: str | None = None) -> str:
    is_multi = len(agent_ids) > 1
    is_sub = subagent_task is not None

    parts = [build_profile(is_multi, is_sub)]
    parts.append(EXPERIMENT_ONTOLOGY)

    if not is_sub:
        parts.append(EXPERIMENT_GENERATOR)

    env_part = build_env(is_multi, is_sub)
    parts.append(env_part)
    parts.append(TAIL)

    prompt = "\n\n".join(parts)

    if is_sub:
        prompt = prompt.replace("[TASK]", subagent_task)

    other_agents = [aid for aid in agent_ids if aid != curr_agent_id]
    other_agents_str = ",".join(other_agents)
    prompt = prompt.replace("[OTHER_AGENTS]", other_agents_str)
    prompt = prompt.replace("[AGENT_ID]", curr_agent_id)
    prompt = prompt.replace("[SUMMARY]", summary)

    return prompt
