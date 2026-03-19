# Commands
Use commands to interact with the environment.

Command: `submit_report`
Parameters: `content`
Function: Submits a report containing `content` to be sent back to the main agent.

Command: `traverse`
Parameters: `hyp_id`, `algorithm`, `max_count`
Function: Ouputs no more than `max_count` hypotheses from a traversal of the Ontology, starting with the Hypothesis with `hyp_id`. If `hyp_id` is set to -1, the traversal starts at a random Hypothesis.

Command: `example`
Parameters: `hyp_id`
Function: Outputs a random experiment that satisfies the conditions of the Hypothesis with id `hyp_id`.

# JSON schema

Command Object:

OR

{
    "command": "submit_report",
    "content": str
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