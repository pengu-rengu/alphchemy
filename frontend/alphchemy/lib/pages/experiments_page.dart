import "package:alphchemy/blocs/experiments_bloc.dart";
import "package:alphchemy/model/experiment_summary.dart";
import "package:alphchemy/pages/editor_page.dart";
import "package:alphchemy/pages/results_page.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ExperimentsPage extends StatelessWidget {
  const ExperimentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      selectedIdx: 0,
      child: BlocBuilder<ExperimentsBloc, ExperimentsState>(
        builder: (context, state) {
          if (state is ExperimentsError) {
            return Center(child: Text(state.message));
          }
          if (state is! ExperimentsLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return ExperimentsList(experiments: state.experiments);
        }
      )
    );
  }
}

class ExperimentsList extends StatelessWidget {
  final List<ExperimentSummary> experiments;

  const ExperimentsList({super.key, required this.experiments});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ExperimentsHeader(),
        const Divider(height: 1),
        Expanded(child: experiments.isEmpty
          ? const Center(child: Text("No experiments yet"))
        : ListView.builder(
            itemCount: experiments.length,
            itemBuilder: (context, index) {
              return ExperimentListTile(summary: experiments[index]);
            }
          )
        )
      ]
    );
  }
}

class ExperimentsHeader extends StatelessWidget {
  const ExperimentsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text("Experiments", style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add),
            label: const Text("Queue Experiment")
          )
        ]
      )
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    final route = MaterialPageRoute<EditorResult?>(
      builder: (routeContext) => const EditorPage()
    );
    final result = await Navigator.of(context).push(route);
    if (!context.mounted) return;
    if (result == null) return;

    final event = QueueExperiment(title: result.title, data: result.data);
    context.read<ExperimentsBloc>().add(event);
  }
}

class ExperimentListTile extends StatelessWidget {
  final ExperimentSummary summary;

  const ExperimentListTile({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(summary.title),
      subtitle: Text(summary.status.label),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _deleteExperiment(context)
      ),
      onTap: summary.status.isCompleted
          ? () => _openResults(context)
          : null
    );
  }

  void _openResults(BuildContext context) {
    final route = MaterialPageRoute<void>(
      builder: (routeContext) => ResultsPage(
        experimentId: summary.id,
        title: summary.title
      )
    );
    final navigator = Navigator.of(context);
    navigator.push(route);
  }

  Future<void> _deleteExperiment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Experiment"),
        content: Text("Delete experiment ${summary.title}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel")
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete")
          )
        ]
      )
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    context.read<ExperimentsBloc>().add(DeleteExperiment(id: summary.id));
  }
}
