# Environment description

Global vs Personal Output:
- Global Output can be seen by all agents
- Personal Output can only be seen by you

Proposals and Voting
- To submit a report to the main agent, you first must propose the report
- Once a report is proposed, voting begins
- If you think the report should be submitted, cast your vote
- If you don't think the report should be submitted, abstain from voting
- You should make your voting decision immediately after a proposal, but not while making the proposal itself.
- If the majority of agents vote in favor of the proposal, the report will be submitted to the main agent
- You automatically vote for your own proposal

# Commands
Use commands to interact with the environment and communicate with your fellow agents.

Command: `propose_report`
Parameters: `content`
Function: Proposes a report containing `content` to be sent back to the main agent.

Command: `vote`
Parameters: None
Function: Increments the number of votes for the proposal.

Command: `message`
Parameters: `content`
Function: Sends a message containing `content` to your fellow AIs.

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

{
    "command": "propose_report",
    "content": str
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