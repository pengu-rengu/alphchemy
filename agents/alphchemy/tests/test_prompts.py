from agents.prompts import make_agent_prompt


def test_make_agent_prompt_generator_mode_includes_generator_submission() -> None:
    prompt = make_agent_prompt(
        ["agent1"],
        "agent1",
        "generator",
        "find better strategies",
        "summary text"
    )

    assert "# Prompt\n\nfind better strategies" in prompt
    assert "submit_experiments" in prompt
    assert "submit_report" not in prompt
    assert "# Search Space JSON schema" in prompt
    assert "Command: `subagent`" in prompt


def test_make_agent_prompt_report_mode_targets_user() -> None:
    prompt = make_agent_prompt(
        ["agent1"],
        "agent1",
        "report",
        "summarize the best findings",
        "summary text"
    )

    assert "# Prompt\n\nsummarize the best findings" in prompt
    assert "submit_report" in prompt
    assert "submit_experiments" not in prompt
    assert "to be sent to the user" in prompt
    assert "# Search Space JSON schema" not in prompt
    assert "Command: `subagent`" in prompt


def test_make_agent_prompt_subagent_report_targets_main_agent() -> None:
    prompt = make_agent_prompt(
        ["agent1", "agent2"],
        "agent1",
        "report",
        "inspect feature sensitivity",
        "summary text",
        True
    )

    assert "# Prompt\n\ninspect feature sensitivity" in prompt
    assert "propose_report" in prompt
    assert "to be sent to the main agent" in prompt
    assert "Command: `subagent`" not in prompt
