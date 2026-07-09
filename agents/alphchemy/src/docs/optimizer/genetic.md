# Genetic Optimizer

This page describes the **genetic optimizer**, which maintains a population of candidate action sequences.

Each iteration, it scores the population, keeps elites, selects parents, applies crossover, applies mutation, updates best sequences, and checks stop conditions.

## Fields

**Fields:**
- `type`:
    - description: optimizer type
    - constraints: must be `genetic`
- `pop_size`:
    - description: number of action sequences in the population
    - constraints: must be integer > 0
- `seq_len`:
    - description: number of actions in each sequence
    - constraints: must be integer > 0
- `n_elites`:
    - description: number of top sequences carried into the next generation unchanged
    - constraints: must be integer >= 0 and <= `pop_size`
- `mut_rate`:
    - description: probability that an action is replaced during mutation
    - constraints: must be between 0.0 and 1.0
- `cross_rate`:
    - description: probability that a child is built from two parents instead of cloned from one
    - constraints: must be between 0.0 and 1.0
- `tourn_size`:
    - description: number of candidates sampled during tournament selection
    - constraints: must be integer >= 1 and <= `pop_size`
- `objectives`:
    - description: map of backtest metric names to weights
    - constraints: every metric must be in `backtest_schema.metrics`
- `random_seed`:
    - description: optional seed for reproducible runs
    - constraints: must be integer or `null`

**Format:**
```
opt:
  type: genetic
  pop_size: ...
  seq_len: ...
  n_elites: ...
  mut_rate: ...
  cross_rate: ...
  tourn_size: ...
  objectives:
    <metric>: <weight>
  random_seed: ...
```

**Example:**
```
opt:
  type: genetic
  pop_size: 40
  seq_len: 12
  n_elites: 4
  mut_rate: 0.15
  cross_rate: 0.7
  tourn_size: 4
  objectives:
    excess_sharpe: 1.0
  random_seed: 123
```

## Tuning

**Controls:**
- `pop_size`:
    - description: larger values explore more candidates per iteration but run slower
- `seq_len`:
    - description: larger values allow more complex networks and increase overfitting risk
- `n_elites`:
    - description: larger values preserve more top candidates
- `mut_rate`:
    - description: larger values explore more but converge slower
- `cross_rate`:
    - description: larger values combine parents more often
- `tourn_size`:
    - description: larger values increase selection pressure

## Further reading

- optimizer/optimizer: Scoring and stop conditions
- experiment/overfitting: Optimizer settings that affect overfitting
