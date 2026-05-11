import "package:alphchemy/blocs/agents_bloc.dart";
import "package:alphchemy/model/agent_system/agent_schema.dart";
import "package:alphchemy/model/agent_system/agent_summary.dart";
import "package:alphchemy/pages/agent_editor_page.dart";
import "package:alphchemy/pages/editor_page.dart";
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
            Expanded(child: AgentSidebarList())
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
      return const Center(child: Text("No agents yet"));
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
            child: Text("Agents")
          ),
          FilledButton.icon(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add, size: 20.0),
            label: const Text("New Agent")
          )
        ]
      )
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    final route = MaterialPageRoute<EditorResult?>(
      builder: (routeContext) => const AgentEditorPage()
    );
    final result = await Navigator.of(context).push(route);
    if (!context.mounted || result == null) {
      return;
    }

    final event = CreateAgent(title: result.title, schemaJson: result.data);
    context.read<AgentsBloc>().add(event);
  }
}

class AgentSidebarTile extends StatelessWidget {
  final AgentSummary summary;
  final bool selected;

  const AgentSidebarTile({super.key, required this.summary, required this.selected});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(summary.title),
      leading: Icon(summary.status == AgentStatus.working ? Icons.hourglass_top : Icons.circle, size: 20.0),
      selected: selected,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _delete(context)
      ),
      onTap: () => _select(context)
    );
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

class AgentStatusIndicator extends StatelessWidget {
  final AgentSummary summary;

  const AgentStatusIndicator({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final icon = summary.hasPendingPrompt ? Icons.hourglass_top : Icons.circle;
    final tooltip = summary.hasPendingPrompt ? "Prompt pending" : summary.status.name;
    return Tooltip(
      child: Icon(icon, size: 12, color: color)
    );
  }

  Color _color(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (summary.hasPendingPrompt) {
      return colorScheme.tertiary;
    }
    if (summary.status == AgentStatus.idle) {
      return colorScheme.primary;
    }
    if (summary.status == AgentStatus.working) {
      return colorScheme.secondary;
    }
    return colorScheme.outline;
  }
}
