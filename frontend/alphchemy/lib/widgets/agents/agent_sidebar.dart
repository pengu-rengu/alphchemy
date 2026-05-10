import "package:alphchemy/blocs/agents_bloc.dart";
import "package:alphchemy/model/agent_summary.dart";
import "package:alphchemy/model/agent_status.dart";
import "package:alphchemy/pages/agent_editor_page.dart";
import "package:alphchemy/pages/editor_page.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class AgentSidebar extends StatelessWidget {
  const AgentSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentsBloc, AgentsBlocState>(
      builder: (context, state) {
        final summaries = <AgentSummary>[];
        int? activeId;
        if (state is AgentsLoaded) {
          summaries.addAll(state.summaries);
          activeId = state.activeSystemId;
        }
        return Column(
          children: [
            const AgentSidebarHeader(),
            const Divider(height: 1),
            Expanded(child: AgentSidebarList(summaries: summaries, activeId: activeId))
          ]
        );
      }
    );
  }
}

class AgentSidebarList extends StatelessWidget {
  final List<AgentSummary> summaries;
  final int? activeId;

  const AgentSidebarList({super.key, required this.summaries, required this.activeId});

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const Center(child: Text("No agents yet"));
    }
    return ListView.builder(
      itemCount: summaries.length,
      itemBuilder: (context, i) => AgentSidebarTile(
        summary: summaries[i],
        selected: summaries[i].id == activeId
      )
    );
  }
}

class AgentSidebarHeader extends StatelessWidget {
  const AgentSidebarHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Expanded(
            child: Text("Agents", maxLines: 1, overflow: TextOverflow.ellipsis)
          ),
          FilledButton.icon(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add),
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
    if (!context.mounted) return;
    if (result == null) return;

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
      selected: selected,
      trailing: SizedBox(
        width: 76,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AgentStatusIndicator(summary: summary),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context)
            )
          ]
        )
      ),
      onTap: () => _select(context)
    );
  }

  void _select(BuildContext context) {
    final event = SelectAgent(id: summary.id);
    context.read<AgentsBloc>().add(event);
  }

  void _delete(BuildContext context) {
    final event = DeleteAgent(id: summary.id);
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
    final tooltip = summary.hasPendingPrompt ? "Prompt pending" : summary.status.label;
    return Tooltip(
      message: tooltip,
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
