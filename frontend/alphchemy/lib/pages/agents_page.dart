import "package:alphchemy/widgets/agents/agent_area.dart";
import "package:alphchemy/widgets/agents/agent_sidebar.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:flutter/material.dart";

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      selectedIdx: 4,
      child: Row(
        children: [
          Expanded(child: AgentArea()),
          VerticalDivider(width: 1),
          SizedBox(width: 300, child: AgentSidebar())
        ]
      )
    );
  }
}