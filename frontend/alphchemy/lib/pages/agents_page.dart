import "package:alphchemy/widgets/agents/agent_area.dart";
import "package:alphchemy/widgets/agents/agent_sidebar.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:flutter/material.dart";

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      selectedIdx: 1,
      child: AgentsBody()
    );
  }
}

class AgentsBody extends StatelessWidget {
  const AgentsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: AgentArea()),
        VerticalDivider(width: 1),
        SizedBox(width: 280, child: AgentSidebar())
      ]
    );
  }
}
