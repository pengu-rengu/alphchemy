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

# Ontology description

- The Ontology is an abstraction of raw experiments and results data. The Ontology consists of Hypotheses, which are claims on whether experiments that satisfy a given set of conditions have a higher value of a given result metric than experiments that do not satisfy the conditions.
- Hypotheses are related to each other based on whether they validate/invalidate each other.
- If two hypotheses agree on whether the experiments that satisfy their conditions have a higher value of a given result metric than experiments that do not, and then jaccard similarity between experiments of the two hypotheses is sufficient, then the hypotheses validate each other.
- Otherwise the two hypothesis invalidate each other.