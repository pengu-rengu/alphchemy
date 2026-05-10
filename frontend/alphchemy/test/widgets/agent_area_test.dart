import "package:alphchemy/model/agent.dart";
import "package:alphchemy/model/agent_status.dart";
import "package:alphchemy/model/agent_system.dart";
import "package:alphchemy/model/agents_state.dart";
import "package:alphchemy/widgets/agents/agent_area.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("keeps input editable but disables send while prompt is pending", (WidgetTester tester) async {
    final agent = _agent(
      status: AgentStatus.idle,
      userPrompt: "queued",
      state: _state()
    );

    await _pumpView(tester, agent);

    final textField = tester.widget<TextField>(find.byType(TextField));
    final sendButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));

    expect(textField.enabled, true);
    expect(sendButton.onPressed, isNull);
  });

  testWidgets("keeps input editable but disables send while agent is working", (WidgetTester tester) async {
    final agent = _agent(
      status: AgentStatus.working,
      state: _state()
    );

    await _pumpView(tester, agent);

    final textField = tester.widget<TextField>(find.byType(TextField));
    final sendButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));

    expect(textField.enabled, true);
    expect(sendButton.onPressed, isNull);
  });

  testWidgets("renders final submissions prominently", (WidgetTester tester) async {
    final agent = _agent(
      status: AgentStatus.idle,
      state: _stateWithSubmission()
    );

    await _pumpView(tester, agent);

    expect(find.text("experiment submission"), findsOneWidget);
    expect(find.textContaining("SPY"), findsOneWidget);
  });

  testWidgets("renders user prompts more prominently than command output", (WidgetTester tester) async {
    const userMessage = AgentMessage(
      role: "user",
      personalOutput: "[USER] Find a setup",
      globalOutput: ""
    );
    const commandMessage = AgentMessage(
      role: "assistant",
      modelOutput: "{\"commands\":[{\"command\":\"message\"}]}",
      personalOutput: "",
      globalOutput: ""
    );

    await _pumpBubble(tester, userMessage);
    final userText = tester.widget<SelectableText>(find.byType(SelectableText));

    expect(find.text("Find a setup"), findsOneWidget);
    expect(userText.style?.fontSize, 12);

    await _pumpBubble(tester, commandMessage);
    final commandText = tester.widget<SelectableText>(find.byType(SelectableText));

    expect(commandText.style?.fontSize, 11);
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  Agent agent
) async {
  final app = MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: AgentSystemView(
        data: agent,
        activeThreadId: "Alpha",
        sending: false
      )
    )
  );
  await tester.pumpWidget(app);
}

Future<void> _pumpBubble(
  WidgetTester tester,
  AgentMessage message
) async {
  final app = MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: Center(
        child: AgentMessageBubble(message: message)
      )
    )
  );
  await tester.pumpWidget(app);
}

Agent _agent({
  required AgentStatus status,
  AgentsState? state,
  String? userPrompt
}) {
  return Agent(
    id: 1,
    title: "Agent",
    lastEdited: DateTime.utc(2026, 5, 10),
    schema: _schema(),
    state: state,
    status: status,
    userPrompt: userPrompt
  );
}

AgentSystemSchema _schema() {
  const agent = AgentConfig(
    id: "Alpha",
    maxContextLen: 15,
    nDelete: 5,
    chatModels: ["deepseek/deepseek-v3.2"],
    summarizeModels: ["deepseek/deepseek-v3.2"]
  );
  return const AgentSystemSchema(agents: [agent], subagentPool: []);
}

AgentsState _state() {
  return AgentsState(
    userPrompt: "",
    systemPrompts: const {},
    summaries: const {},
    agentContexts: const {
      "Alpha": [
        AgentMessage(
          role: "user",
          personalOutput: "[USER] Find a setup",
          globalOutput: ""
        ),
        AgentMessage(
          role: "assistant",
          modelOutput: "{\"commands\":[]}",
          personalOutput: "",
          globalOutput: ""
        ),
        AgentMessage(
          role: "user",
          personalOutput: "",
          globalOutput: "[Beta] I agree"
        )
      ]
    },
    commands: const [],
    params: const [],
    proposalState: AgentProposalState.idle(),
    agentOrder: const ["Alpha"],
    turn: 0,
    isSubagent: false
  );
}

AgentsState _stateWithSubmission() {
  const submission = AgentSubmission(
    type: "experiment",
    content: {
      "experiment": {
        "symbol": "SPY"
      }
    }
  );
  const proposalState = AgentProposalState(
    state: "submission",
    type: "experiment",
    submission: submission
  );
  return _state().copyWith(proposalState: proposalState);
}
