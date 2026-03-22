from agents.prompts import make_agent_prompt, make_planner_prompt

if __name__ == "__main__":
    print(make_agent_prompt(["Agent 1", "Agent 2"], "Agent 1", "plan", "summary", "subagent task"))