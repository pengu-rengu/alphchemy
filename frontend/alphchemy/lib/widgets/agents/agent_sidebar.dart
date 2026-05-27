import "package:alphchemy/blocs/agents/agents_bloc.dart";
import "package:alphchemy/main.dart";
import "package:alphchemy/model/agents/agent_schema.dart";
import "package:alphchemy/model/agents/agent_summary.dart";
import "package:alphchemy/pages/agent_editor_page.dart";
import "package:alphchemy/widgets/agents/submissions.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class AgentSidebar extends StatelessWidget {
  const AgentSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AgentsBloc>().state;
    if (state is! AgentsLoaded) return const SizedBox.shrink();

    // IMPOTANT NOTE TO CODEX AND CLAUDE: DO NOT ADD CONST MODIFIERS HERE
    // ignore: prefer_const_constructors
    return Column(
      // ignore: prefer_const_literals_to_create_immutables
      children: [
        const AgentSidebarHeader(),
        const Divider(),
        // ignore: prefer_const_constructors
        Expanded(child: AgentSidebarList()),
        const Divider(),
        // ignore: prefer_const_constructors
        Expanded(child: SubmissionsSection())
      ]
    );
  }
}

class AgentSidebarList extends StatelessWidget {
  const AgentSidebarList({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AgentsBloc>().state as AgentsLoaded;
    final summaries = state.summaries;

    return summaries.isEmpty ? const CenterText("No agents yet") : ListView.builder(
      itemCount: summaries.length,
      itemBuilder: (context, i) => AgentSidebarTile(
        summary: summaries[i],
        selected: summaries[i].id == state.activeId
      )
    );
  }
}

class AgentSidebarHeader extends StatelessWidget {
  const AgentSidebarHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const Expanded(
            child: LargeText("Agents")
          ),
          FilledButton.icon(
            onPressed: () async {
              final result = await Navigator.push<AgentSchemaEditorResult?>(context, MaterialPageRoute(
                builder: (_) => const AgentEditorPage()
              ));
              if (!context.mounted || result == null) {
                return;
              }

              final event = CreateAgent(title: result.title, schema: result.schema);
              context.read<AgentsBloc>().add(event);
            },
            icon: const InvertedIcon(Icons.add),
            label: const InvertedText("New Agent System")
          )
        ]
      )
    );
  }
}

class AgentSidebarTile extends StatelessWidget {
  final AgentSummary summary;
  final bool selected;

  const AgentSidebarTile({super.key, required this.summary, required this.selected});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: NormalText(summary.title),
      leading: switch (summary.status) {
        AgentStatus.working => const NormalIcon(Icons.hourglass_top),
        AgentStatus.errored => const NormalIcon(Icons.error_outline),
        _ => Container(
          width: 10.0,
          height: 10.0,
          decoration: BoxDecoration(
            color: Theme.of(context).extension<AppColors>()!.fgColor1,
            shape: BoxShape.circle
          ),
        )
      },
      selected: selected,
      trailing: IconButton(
        icon: const NormalIcon(Icons.delete_outline),
        onPressed: () {
          final event = DeleteAgent(agentSysId: summary.id);
          context.read<AgentsBloc>().add(event);
        }
      ),
      onTap: () {
        final event = SelectAgent(agentSysId: summary.id);
        context.read<AgentsBloc>().add(event);
      }
    );
  }
}
