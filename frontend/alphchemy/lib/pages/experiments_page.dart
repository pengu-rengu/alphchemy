import "package:alphchemy/blocs/experiments_bloc.dart";
import "package:alphchemy/model/experiment_summary.dart";
import "package:alphchemy/pages/editor_page.dart";
import "package:alphchemy/pages/results_page.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ExperimentsPage extends StatelessWidget {
  const ExperimentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      selectedIdx: 0,
      child: BlocBuilder<ExperimentsBloc, ExperimentsState>(
        builder: (context, state) {
          if (state is ExperimentsError) {
            return Center(child: NormalText(state.message));
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
          ? const Center(child: NormalText("No experiments yet"))
        : ListView.builder(
            padding: const EdgeInsets.all(10.0),
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
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        children: [
          const LargeText("Experiments"),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _openEditor(context),
            icon: const InvertedIcon(Icons.add),
            label: const InvertedText("Queue Experiment")
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
    return PaddedCard(child: ListTile(
      dense: true,
      title: NormalText(summary.title),
      subtitle: NormalText(summary.status.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: "Clone experiment",
            icon: const NormalIcon(Icons.content_copy),
            onPressed: () => _cloneExperiment(context)
          ),
          IconButton(
            tooltip: "Delete experiment",
            icon: const NormalIcon(Icons.delete_outline),
            onPressed: () => _deleteExperiment(context)
          )
        ]
      ),
      onTap: _tapExperiment(context)
    ));
  }

  VoidCallback? _tapExperiment(BuildContext context) {
    if (summary.status.isCompleted) {
      return () => _openResults(context);
    }

    if (summary.status.isErrored) {
      return () => _showErrorMessage(context);
    }

    return null;
  }

  void _openResults(BuildContext context) {
    final route = MaterialPageRoute<void>(
      builder: (routeContext) => ResultsPage(initialExperimentId: summary.id)
    );
    final navigator = Navigator.of(context);
    navigator.push(route);
  }

  Future<void> _cloneExperiment(BuildContext context) async {
    late Map<String, dynamic> experimentJson;

    try {
      experimentJson = await _loadExperimentJson(context);
    } catch (err) {
      if (!context.mounted) {
        return;
      }
      await _showCloneError(context, err.toString());
      return;
    }

    if (!context.mounted) {
      return;
    }

    final copyTitle = "Copy of ${summary.title}";
    final route = MaterialPageRoute<EditorResult?>(
      builder: (routeContext) => EditorPage(
        json: experimentJson,
        initialTitle: copyTitle
      )
    );
    final result = await Navigator.of(context).push(route);
    if (!context.mounted) return;
    if (result == null) {
      return;
    }

    final event = QueueExperiment(title: result.title, data: result.data);
    context.read<ExperimentsBloc>().add(event);
  }

  Future<Map<String, dynamic>> _loadExperimentJson(BuildContext context) async {
    final client = context.read<SupabaseClient>();
    final table = client.from("experiments");
    final query = table.select("experiment");
    final filtered = query.eq("id", summary.id);
    final row = await filtered.single();
    final json = Map<String, dynamic>.from(row);
    final experiment = json["experiment"] as Map<String, dynamic>?;
    return experiment == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(experiment);
  }

  Future<void> _showErrorMessage(BuildContext context) async {
    final message = summary.errorMessage ?? "No error message available";
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: LargeText(summary.title),
        content: NormalText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const NormalText("Close")
          )
        ]
      )
    );
  }

  Future<void> _showCloneError(BuildContext context, String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LargeText("Clone Experiment"),
        content: NormalText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const NormalText("Close")
          )
        ]
      )
    );
  }

  Future<void> _deleteExperiment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LargeText("Delete Experiment"),
        content: NormalText("Delete experiment ${summary.title}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const NormalText("Cancel")
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const NormalText("Delete")
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
