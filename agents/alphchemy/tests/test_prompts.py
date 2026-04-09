from agents.prompts import make_agent_prompt


def test_make_agent_prompt_main_agent_includes_both_modes() -> None:
    prompt = make_agent_prompt(
        ["agent1"],
        "agent1",
        "find better strategies",
        "summary text"
    )

    assert "# Prompt\n\nfind better strategies" in prompt
    assert "submit_experiments" in prompt
    assert "submit_report" in prompt
    assert "Command: `subagent`" in prompt


def test_make_agent_prompt_main_agent_includes_generator_docs() -> None:
    prompt = make_agent_prompt(
        ["agent1"],
        "agent1",
        "summarize the best findings",
        "summary text"
    )

    assert "submit_report" in prompt
    assert "submit_experiments" in prompt
    assert "to be sent to the user" in prompt
    assert "Command: `subagent`" in prompt


def test_make_agent_prompt_subagent_report_targets_main_agent() -> None:
    prompt = make_agent_prompt(
        ["agent1", "agent2"],
        "agent1",
        "inspect feature sensitivity",
        "summary text",
        True
    )

    assert "# Prompt\n\ninspect feature sensitivity" in prompt
    assert "propose_report" in prompt
    assert "propose_experiments" not in prompt
    assert "to be sent to the main agent" in prompt
    assert "Command: `subagent`" not in prompt


def test_make_agent_prompt_documents_select_based_analyze_data() -> None:
    prompt = make_agent_prompt(
        ["agent1"],
        "agent1",
        "analyze experiments",
        "summary text"
    )

    assert "Parameters: `select`, `filters`" in prompt
    assert "\"select\": [str]" in prompt
    assert "summary block for each selected path" in prompt
    assert "All selected paths must resolve to numeric values" in prompt
    assert "Parameters: `path`, `filters`" not in prompt
