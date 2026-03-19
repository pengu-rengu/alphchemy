# Commands
Use commands to interact with the environment.

Command: `subagent`
Parameters: `task`, `n_agents`
Function: Spins up a sub-agent system with `n_agents` to perform `task`. The sub-agent system will run until it submits a report. The report will be returned to you.

Command: `submit_experiments`
Parameters: `code`
Function: Submits python `code` that generates experiments to be run. The code should have a function `generate_experiments` that returns an array of 1000 experiment JSON objects. It should not import random or any other external libraries. The code should be enclosed in a fenced markdown code block, starting with "```python" and ending with "```".

Command: `traverse`
Parameters: `hyp_id`, `algorithm`, `max_count`
Function: Ouputs no more than `max_count` hypotheses from a traversal of the Ontology, starting with the Hypothesis with `hyp_id`. If `hyp_id` is set to -1, the traversal starts at a random Hypothesis.

Command: `example`
Parameters: `hyp_id`
Function: Outputs a random experiment that satisfies the conditions of the Hypothesis with id `hyp_id`.

# JSON schema

Command Object:

{
    "command": "subagent",
    "task": str,
    "n_agents": int
}

OR

{
    "command": "submit_experiments",
    "code": str
}

OR

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

Response Object:

{
    "thought": str,
    "commands": [array of command objects]
}