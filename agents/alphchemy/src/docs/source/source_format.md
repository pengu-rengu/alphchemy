# Experiment source format

This page describes the **experiment source format**, which is the text syntax used to define and queue experiments.

## Format Rules

**Rules:**
- indentation:
    - description: use two spaces per indentation level
- scalar:
    - description: use `key: value`
- nested object:
    - description: use `key:` followed by deeper-indented fields
- scalar list:
    - description: use comma-separated inline values
- strings:
    - description: do not use quotes unless a query filter value requires them
- booleans:
    - description: use `true` or `false`
- optional values:
    - description: use `null`
- object collections:
    - description: use keyed maps
- timestamps:
    - description: `start_timestamp` and `end_timestamp` accept ISO 8601 dates

The parser selects the strategy type from `strategy.base_net.type`. `base_net`, `actions`, and `penalties` must all use matching `logic` or `decision` shapes.

## Further reading

- source/example: Complete decision strategy example
- experiment/experiment: Top-level experiment fields
- features/indicators: Feature-specific parameters
