import "package:alphchemy/blocs/experiments_bloc.dart";
import "package:alphchemy/model/experiment_summary.dart";
import "package:alphchemy/pages/editor_page.dart";
import "package:alphchemy/repositories/experiment_repository.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:uuid/uuid.dart";

const _uuid = Uuid();

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
            itemBuilder: (context, i) {
              return ExperimentListTile(summary: experiments[i]);
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
            onPressed: () async {
              final id = _uuid.v4();
              final repository = context.read<ExperimentRepository>();
              final route = MaterialPageRoute<void>(
                builder: (_) => EditorPage(
                  experimentId: id,
                  repository: repository
                )
              );

              context.read<ExperimentsBloc>().add(CreateExperiment(id: id));
              await Navigator.of(context).push(route);
              if (!context.mounted) {
                return;
              }
              context.read<ExperimentsBloc>().add(const LoadExperiments());
            },
            icon: const Icon(Icons.add),
            label: const Text("New Experiment")
          )
        ]
      )
    );
  }
}

class ExperimentListTile extends StatelessWidget {
  final ExperimentSummary summary;

  const ExperimentListTile({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final dateText = _formatDate(summary.createdAt);
    final repository = context.read<ExperimentRepository>();
    final route = MaterialPageRoute<void>(
      builder: (_) => EditorPage(
        experimentId: summary.id,
        repository: repository
      )
    );

    return ListTile(
      title: Text(summary.id),
      subtitle: Text(dateText),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _deleteExperiment(context)
      ),
      onTap: () async {
        await Navigator.of(context).push(route);
        if (!context.mounted) {
          return;
        }
        context.read<ExperimentsBloc>().add(const LoadExperiments());
      }
    );
  }

  Future<void> _deleteExperiment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Experiment"),
        content: Text("Delete experiment ${summary.id}?"),
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

  static String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, "0");
    final day = date.day.toString().padLeft(2, "0");
    return "$year-$month-$day";
  }
}
