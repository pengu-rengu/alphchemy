import "package:alphchemy/model/agent_system/agent_contexts.dart";
import "package:alphchemy/model/agent_system/agent_schema.dart";
import "package:alphchemy/model/agent_system/agent_system.dart";
import "package:alphchemy/model/agent_system/submission.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("parses null state as empty contexts", () {
    final agentSystem = AgentSystem.fromJson(agentRow(null));

    expect(agentSystem.agentIds, ["Main", "Critic"]);
    expect(agentSystem.contexts.threads["Main"], isEmpty);
    expect(agentSystem.contexts.threads["Critic"], isEmpty);
    expect(agentSystem.status, AgentStatus.created);
    expect(agentSystem.submissions, isEmpty);
  });

  test("parses initialized state contexts", () {
    final agentSystem = AgentSystem.fromJson(agentRow({
      "agent_contexts": {
        "Main": [
          {
            "role": "user",
            "personal_output": "personal note",
            "global_output": ""
          }
        ]
      }
    }));

    final mainMessages = agentSystem.contexts.threads["Main"]!;
    final criticMessages = agentSystem.contexts.threads["Critic"]!;

    expect(mainMessages.length, 1);
    expect(mainMessages.first, isA<UserMessage>());
    expect(criticMessages, isEmpty);
  });

  test("parses raw json notebook submissions", () {
    final row = agentRow(null);
    row["submissions"] = [
      {
        "type": "notebook",
        "submission": {
          "title": "Notebook",
          "queries": [
            {
              "id": "query-1",
              "select": ["results.mean.test_results.excess_sharpe"],
              "filters": []
            }
          ],
          "notes": [],
          "layout": {
            "left": ["query-1"],
            "right": []
          }
        }
      }
    ];

    final agentSystem = AgentSystem.fromJson(row);
    final submission = agentSystem.submissions.first as NotebookSubmission;

    expect(submission.title, "Notebook");
    expect(submission.notebookJson["queries"], isA<List<dynamic>>());
    expect(submission.notebookJson["layout"], isA<Map<String, dynamic>>());
    expect(submission.toJson(), row["submissions"].first);
  });

  test("parses legacy string notebook submissions", () {
    final row = agentRow(null);
    row["submissions"] = [
      {
        "type": "notebook",
        "submission": {
          "title": "Notebook",
          "notebook": "plain notebook"
        }
      }
    ];

    final agentSystem = AgentSystem.fromJson(row);
    final submission = agentSystem.submissions.first as NotebookSubmission;

    expect(submission.notebookJson["notebook"], "plain notebook");
    expect(submission.toJson(), row["submissions"].first);
  });
}

Map<String, dynamic> agentRow(dynamic state) {
  return {
    "id": 1,
    "title": "Demo",
    "last_edited": "2026-05-19T12:00:00Z",
    "schema": {
      "agents": [
        {"id": "Main"},
        {"id": "Critic"}
      ]
    },
    "state": state,
    "status": "created",
    "user_prompt": null,
    "submissions": []
  };
}
