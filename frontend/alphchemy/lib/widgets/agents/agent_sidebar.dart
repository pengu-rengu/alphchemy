import "package:alphchemy/blocs/agents/agents_bloc.dart";
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
    return BlocBuilder<AgentsBloc, AgentsState>(
      builder: (context, state) {
        if (state is! AgentsLoaded) {
          return const SizedBox();
        }
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
    );
  }
}

class AgentSidebarList extends StatelessWidget {
  const AgentSidebarList({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AgentsBloc>().state as AgentsLoaded;
    final summaries = state.summaries;

    if (summaries.isEmpty) {
      return const Center(child: NormalText("No agents yet"));
    }
    return ListView.builder(
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
      leading: NormalIcon(_statusIcon()),
      selected: selected,
      trailing: IconButton(
        icon: const NormalIcon(Icons.delete_outline),
        onPressed: () => _delete(context)
      ),
      onTap: () => _select(context)
    );
  }

  IconData _statusIcon() {
    if (summary.status == AgentStatus.working) {
      return Icons.hourglass_top;
    }

    if (summary.status == AgentStatus.errored) {
      return Icons.error_outline;
    }

    return Icons.circle;
  }

  void _select(BuildContext context) {
    final event = SelectAgent(agentSysId: summary.id);
    context.read<AgentsBloc>().add(event);
  }

  void _delete(BuildContext context) {
    final event = DeleteAgent(agentSysId: summary.id);
    context.read<AgentsBloc>().add(event);
  }
}
