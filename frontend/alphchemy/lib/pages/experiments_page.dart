import "dart:convert";

import "package:alphchemy/blocs/experiments/experiments_bloc.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/model/experiment_summary.dart";
import "package:alphchemy/pages/editor_page.dart";
import "package:alphchemy/pages/results_page.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ExperimentsPage extends StatelessWidget {
  const ExperimentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ExperimentsBloc>(
      create: (_) {
        final bloc = ExperimentsBloc(client: context.read<SupabaseClient>());
        bloc.add(const LoadExperiments());
        return bloc;
      },
      child: const PageScaffold(
        selectedIdx: 0,
        child: ExperimentsArea()
      )
    );
  }
}

class ExperimentsArea extends StatelessWidget {
  const ExperimentsArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExperimentsBloc, ExperimentsState>(
      builder: (context, state) {
        return Column(
          children: [
            // ignore: prefer_const_constructors
            ExperimentsHeader(),
            const Divider(height: 1),
            switch (state) {
              ExperimentsInitial() => const LoadingIndicator(),
              ExperimentsError() => CenterText(state.message, expanded: true),
              // ignore: prefer_const_constructors
              ExperimentsLoaded() => ExperimentsTable()
            }
          ]
        );
      }
    );
  }
}

class ExperimentsHeader extends StatelessWidget {
  const ExperimentsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ExperimentsBloc>();

    return Header(
      left: const [LargeText("Experiments")],
      right: [FilledButton.icon(
        onPressed: () async {
          final result = await Navigator.push<ExperimentEditorResult?>(context, MaterialPageRoute(
            builder: (routeContext) => const EditorPage()
          ));
          if (!context.mounted || result == null) return;

          final event = QueueExperiment(title: result.title, experiment: result.experiment);
          bloc.add(event);
        },
        icon: const InvertedIcon(Icons.add),
        label: const InvertedText("Queue Experiment")
      )],
      errorMessage: (() {
        final state = bloc.state;
        return state is ExperimentsLoaded ? state.errorMessage : null;
      })(),
    );
  }
}

class ExperimentsTable extends StatelessWidget {
  const ExperimentsTable({super.key});

  @override
  Widget build(BuildContext context) {
    final loaded = context.read<ExperimentsBloc>().state as ExperimentsLoaded;
    final filter = loaded.filter;
    final summaries = loaded.summaries;

    final filtered = filter == "all"
      ? summaries
      : summaries.where((summary) => summary.status.name == filter).toList();

    return Expanded(child: Column(
      children: [
        // ignore: prefer_const_constructors
        FilterBar(),
        const Divider(height: 1),
        const ColumnHeaders(),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
            ? const CenterText("No experiments match the current filter")
            : ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, idx) => const Divider(height: 1),
                itemBuilder: (context, idx) => ExperimentRow(summary: filtered[idx])
              )
        )
      ]
    ));
  }
}

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      ["all", "All"],
      ["running", "Running"],
      ["queued", "Queued"],
      ["completed", "Completed"],
      ["errored", "Errored"]
    ];

    final loaded = context.read<ExperimentsBloc>().state as ExperimentsLoaded;
    final filter = loaded.filter;

    final counts = <String, int>{"all": loaded.summaries.length};
    for (final summary in loaded.summaries) {
      final key = summary.status.name;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: Row(children: [
        for (final tab in tabs)
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: ChoiceChip(
              selected: tab[0] == filter,
              onSelected: (_) => context.read<ExperimentsBloc>().add(FilterExperiments(filter: tab[0])),
              label: Row(mainAxisSize: MainAxisSize.min, children: [
                tab[0] == filter ? InvertedText(tab[1]) : NormalText(tab[1]),
                const SizedBox(width: 6.0),
                tab[0] == filter ? InvertedText((counts[tab[0]] ?? 0).toString()) : NormalText((counts[tab[0]] ?? 0).toString())
              ])
            )
          )
      ])
    );
  }
}

class ColumnHeaders extends StatelessWidget {
  const ColumnHeaders({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(children: [
        SizedBox(width: 10.0),
        ListCell(value: "Title", flex: 6, alignLeft: true),
        ListCell(value: "Status", flex: 3),
        ListCell(value: "Last Updated"),
        ListCell(value: "")
      ])
    );
  }
}

class ExperimentRow extends StatelessWidget {
  final ExperimentSummary summary;

  const ExperimentRow({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final status = summary.status;
    final lastUpdated = relativeTime(summary.lastEdited);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: status == ExperimentStatus.completed || status == ExperimentStatus.errored ? () {
        if (status == ExperimentStatus.completed) {
          Navigator.push(context, MaterialPageRoute(
            builder: (routeContext) => ResultsPage(experimentId: summary.id, title: summary.title)
          ));
        } else {
          errorDialog(context: context, message: summary.errorMessage ?? "No error message available");
        }
      } : null,
      title: Row(children: [
        const SizedBox(width: 10.0),
        ListCell(value: summary.title, flex: 6, alignLeft: true),
        StatusIndicator(status: status),
        ListCell(value: lastUpdated),
        Expanded(flex: 2, child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: "Clone experiment",
            onPressed: () async {
              late final String experiment;
              try {
                final table = context.read<SupabaseClient>().from("experiments");
                final query = table.select("experiment");
                final json = await query.eq("id", summary.id).single();
                const encoder = JsonEncoder.withIndent("  ");
                experiment = encoder.convert(json["experiment"]);
              } catch (error) {
                if (!context.mounted) return;
                errorDialog(context: context, message: error.toString());
                return;
              }

              if (!context.mounted) return;
              final result = await Navigator.push(context, MaterialPageRoute<ExperimentEditorResult?>(
                builder: (routeContext) => EditorPage(experiment: experiment, title: "Copy of ${summary.title}")
              ));

              if (!context.mounted || result == null) return;
              final event = QueueExperiment(title: result.title, experiment: result.experiment);
              context.read<ExperimentsBloc>().add(event);
            },
            icon: const NormalIcon(Icons.content_copy)
          ),
          IconButton(
            tooltip: "Delete experiment",
            onPressed: () async {
              final confirmed = await confirmDeleteDialog(context: context, title: summary.title);
              if (!context.mounted || !confirmed) return;

              final event = DeleteExperiment(id: summary.id);
              context.read<ExperimentsBloc>().add(event);
            },
            icon: const NormalIcon(Icons.delete_outline)
          )
        ]))
      ])
    );
  }
}

class StatusIndicator extends StatelessWidget {
  final ExperimentStatus status;

  const StatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      ExperimentStatus.completed => Icons.check_circle_outline,
      ExperimentStatus.running => Icons.sync,
      ExperimentStatus.queued => Icons.schedule,
      ExperimentStatus.errored => Icons.error_outline
    };

    return Expanded(
      flex: 3,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        NormalIcon(icon),
        const SizedBox(width: 5.0),
        NormalText(status.name)
      ])
    );
  }
}
