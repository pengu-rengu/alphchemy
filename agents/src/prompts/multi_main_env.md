# Environment description

Global vs Personal Output:
- Global Output can be seen by all agents
- Personal Output can only be seen by you

Proposals and Voting
- To run experiments, you first must propose python code to generate those experiments
- Once experiment generation code is proposed, voting begins
- If you think the experiments to should be run, cast your vote
- If you don't think the experiments should be run, abstain from voting
- You should make your voting decision immediately after a proposal, but not while making the proposal itself.
- If the majority of agents vote in favor of the proposal, the generated experiments will run
- You automatically vote for your own proposal

# Commands
Use commands to interact with the environment and communicate with your fellow agents.

Command: `subagent`
Parameters: `task`, `n_agents`
Function: Spins up a sub-agent system with `n_agents` to perform `task`. The sub-agent system will run until it submits a report. The report will be returned to you.

Command: `propose_experiments`
Parameters: `code`
Function: Proposes python `code` that generates experiments to be run. The code should have a function `generate_experiments` that returns an array of 1000 experiment JSON objects. It should not import random or any other external libraries. The code should be enclosed in a fenced markdown code block, starting with "```python" and ending with "```".

Command: `vote`
Parameters: None
Function: Increments the number of votes for the proposal.

Command: `message`
Parameters: `contents`
Function: Sends a message containing `contents` to your fellow AIs.

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

{
    "command": "subagent",
    "task": str,
    "n_agents": int
}

OR

{
    "command": "propose_experiments",
    "code": str
}

OR

{
    "command": "vote"
}

OR

{
    "command": "message",
    "content": str
}



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