import "package:alphchemy/model/agent.dart";
import "package:alphchemy/model/agent_status.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("parses Supabase agent rows with nullable state and prompt", () {
    final row = _agentRow(status: "created");

    final agent = Agent.fromJson(row);

    expect(agent.id, 7);
    expect(agent.title, "Research Agent");
    expect(agent.status, AgentStatus.created);
    expect(agent.state, isNull);
    expect(agent.userPrompt, isNull);
    expect(agent.summary.hasPendingPrompt, false);
  });

  test("parses worker state, user messages, and final submissions", () {
    final row = _agentRow(
      status: "idle",
      state: _stateJson(),
      userPrompt: "pending prompt"
    );

    final agent = Agent.fromJson(row);
    final state = agent.state;
    final submission = state?.finalSubmission;
    final alphaContext = state?.agentContexts["Alpha"] ?? const [];

    expect(agent.status, AgentStatus.idle);
    expect(agent.summary.hasPendingPrompt, true);
    expect(agent.userPrompt, "pending prompt");
    expect(state?.agentOrder, ["Alpha", "Beta"]);
    expect(alphaContext.first.isUserPrompt, true);
    expect(submission?.type, "experiment");
    expect(submission?.content["experiment"], {"symbol": "SPY"});
  });

  test("parses all agent statuses", () {
    expect(AgentStatus.fromJson("created"), AgentStatus.created);
    expect(AgentStatus.fromJson("idle"), AgentStatus.idle);
    expect(AgentStatus.fromJson("working"), AgentStatus.working);
    expect(AgentStatus.fromJson("unknown"), AgentStatus.created);
    expect(AgentStatus.idle.canReceivePrompt, true);
    expect(AgentStatus.working.canReceivePrompt, false);
  });
}

Map<String, dynamic> _agentRow({
  String status = "created",
  Map<String, dynamic>? state,
  String? userPrompt
}) {
  return {
    "id": 7,
    "last_edited": "2026-05-10T14:00:00Z",
    "title": "Research Agent",
    "schema": _schemaJson(),
    "state": state,
    "status": status,
    "user_prompt": userPrompt
  };
}

Map<String, dynamic> _schemaJson() {
  return {
    "agents": [
      {
        "id": "Alpha",
        "max_context_len": 15,
        "n_delete": 5,
        "chat_models": ["deepseek/deepseek-v3.2"],
        "summarize_models": ["deepseek/deepseek-v3.2"]
      },
      {
        "id": "Beta",
        "max_context_len": 15,
        "n_delete": 5,
        "chat_models": ["deepseek/deepseek-v3.2"],
        "summarize_models": ["deepseek/deepseek-v3.2"]
      }
    ],
    "subagent_pool": []
  };
}

Map<String, dynamic> _stateJson() {
  return {
    "user_prompt": "Find a robust setup",
    "system_prompts": {
      "Alpha": "alpha system",
      "Beta": "beta system"
    },
    "summaries": {
      "Alpha": "",
      "Beta": ""
    },
    "agent_contexts": {
      "Alpha": [
        {
          "role": "user",
          "personal_output": "[USER] Find a robust setup",
          "global_output": ""
        },
        {
          "role": "assistant",
          "model_output": "{\"commands\":[]}"
        }
      ],
      "Beta": [
        {
          "role": "user",
          "personal_output": "",
          "global_output": "[Alpha] Looks promising"
        }
      ]
    },
    "commands": [],
    "params": [],
    "proposal_state": {
      "state": "submission",
      "type": "experiment",
      "submission": {
        "experiment": {
          "symbol": "SPY"
        }
      }
    },
    "agent_order": ["Alpha", "Beta"],
    "turn": 0,
    "is_subagent": false
  };
}
