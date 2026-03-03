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

Command: `recent_arxiv`
Parameters: `category`, `max_count`
Function: Requests no more than `max_count` papers from arXiv that are categorized under `category`.

Command: `arxiv_text`
Parameters: `paper_id`, `max_pages`
Function: Outputs no more than `max_pages` pages of the arXiv paper with id `paper_id`.

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

OR

{
    "command": "recent_arxiv",
    "category": one of "quantitative finance", "computational finance", "statistics", "statistics methodology", "machine learning",
    "max_count": int 1 - 10

}

OR

{
    "command": "arxiv_text",
    "paper_id": str,
    "max_pages": int 1 - 5
}

Response Object:

{
    "thought": str,
    "commands": [array of command objects]
}