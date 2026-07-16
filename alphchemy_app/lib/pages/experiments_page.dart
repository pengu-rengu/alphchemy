import "package:alphchemy_app/blocs/experiments/experiments_bloc.dart";
import "package:alphchemy_app/widgets/dialog_utils.dart";
import "package:alphchemy_app/model/experiment_summary.dart";
import "package:alphchemy_app/pages/editor_page.dart";
import "package:alphchemy_app/pages/results_page.dart";
import "package:alphchemy_app/utils.dart";
import "package:alphchemy_app/widgets/misc_widgets.dart";
import "package:alphchemy_app/widgets/page_scaffold.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";
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
            const FDivider(),
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
      right: [FButton(
        onPress: () async {
          final input = await openByIdDialog(context: context);
          if (!context.mounted || input == null) return;

          final id = int.tryParse(input);
          if (id == null) {
            errorDialog(context: context, message: "Invalid experiment ID: $input");
            return;
          }

          late final Map<String, dynamic>? row;
          try {
            final table = context.read<SupabaseClient>().from("experiments");
            final query = table.select("title, status, results");
            row = await query.eq("id", id).maybeSingle();
          } catch (error) {
            if (!context.mounted) return;
            errorDialog(context: context, message: error.toString());
            return;
          }

          if (!context.mounted) return;
          if (row == null) {
            errorDialog(context: context, message: "Experiment $id not found");
            return;
          }

          final status = ExperimentStatus.fromJson(row["status"]);
          if (status == ExperimentStatus.completed) {
            final title = row["title"] as String;
            Navigator.push(context, MaterialPageRoute(
              builder: (routeContext) => ResultsPage(experimentId: id, title: title)
            ));
          } else if (status == ExperimentStatus.errored) {
            final results = row["results"];
            final errorMessage = results is Map<String, dynamic> ? results["error"] as String? : null;
            errorDialog(context: context, message: errorMessage ?? "No error message available");
          } else {
            errorDialog(context: context, message: "Experiment $id is ${status.name}");
          }
        },
        prefix: const InvertedIcon(Icons.search),
        child: const InvertedText("Open By ID")
      ),
      const SizedBox(width: 10.0),
      FButton(
        onPress: () async {
          final result = await Navigator.push<ExperimentEditorResult?>(context, MaterialPageRoute(
            builder: (routeContext) => const EditorPage()
          ));
          if (!context.mounted || result == null) return;

          final event = QueueExperiment(title: result.title, source: result.source);
          bloc.add(event);
        },
        prefix: const InvertedIcon(Icons.add),
        child: const InvertedText("Queue Experiment")
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
    final summaries = loaded.summaries;

    return Expanded(child: Column(
      children: [
        // ignore: prefer_const_constructors
        FilterBar(),
        const FDivider(),
        const ColumnHeaders(),
        const FDivider(),
        Expanded(
          child: summaries.isEmpty
            ? const CenterText("No experiments match the current filter")
            : ListView.separated(
                itemCount: summaries.length,
                separatorBuilder: (context, idx) => const FDivider(),
                itemBuilder: (context, idx) => ExperimentRow(summary: summaries[idx])
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
    const statusTabs = [
      (ExperimentStatusFilter.all, "All"),
      (ExperimentStatusFilter.running, "Running"),
      (ExperimentStatusFilter.queued, "Queued"),
      (ExperimentStatusFilter.completed, "Completed"),
      (ExperimentStatusFilter.errored, "Errored")
    ];
    const visibilityTabs = [
      (ExperimentVisibilityFilter.all, "All"),
      (ExperimentVisibilityFilter.private, "Private"),
      (ExperimentVisibilityFilter.public, "Public")
    ];

    final loaded = context.read<ExperimentsBloc>().state as ExperimentsLoaded;
    final statusFilter = loaded.statusFilter;
    final visibilityFilter = loaded.visibilityFilter;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(children: [
        const NormalText("Status:"),
        const SizedBox(width: 5.0),
        for (final tab in statusTabs)
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: FButton(
              variant: tab.$1 == statusFilter ? FButtonVariant.primary : FButtonVariant.outline,
              onPress: () {
                final event = FilterExperiments(statusFilter: tab.$1, visibilityFilter: visibilityFilter);
                context.read<ExperimentsBloc>().add(event);
              },
              child: tab.$1 == statusFilter ? InvertedText(tab.$2) : NormalText(tab.$2)
            )
          ),
        const SizedBox(width: 10.0),
        const NormalText("Visibility:"),
        const SizedBox(width: 5.0),
        for (final tab in visibilityTabs)
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: FButton(
              variant: tab.$1 == visibilityFilter ? FButtonVariant.primary : FButtonVariant.outline,
              onPress: () {
                final event = FilterExperiments(statusFilter: statusFilter, visibilityFilter: tab.$1);
                context.read<ExperimentsBloc>().add(event);
              },
              child: tab.$1 == visibilityFilter ? InvertedText(tab.$2) : NormalText(tab.$2)
            )
          ),
        const Spacer(),
        FButton.icon(
          variant: FButtonVariant.ghost,
          onPress: () => context.read<ExperimentsBloc>().add(const LoadExperiments()),
          child: const NormalIcon(Icons.refresh)
        ),
        // ignore: prefer_const_constructors
        Pager()
      ])
    );
  }
}

class Pager extends StatelessWidget {
  const Pager({super.key});

  @override
  Widget build(BuildContext context) {
    final loaded = context.read<ExperimentsBloc>().state as ExperimentsLoaded;
    final page = loaded.page;
    final displayPage = page + 1;
    final prevPage = page - 1;
    final nextPage = page + 1;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      FButton.icon(
        variant: FButtonVariant.ghost,
        onPress: page == 0 ? null : () => context.read<ExperimentsBloc>().add(ChangePage(page: prevPage)),
        child: const NormalIcon(Icons.chevron_left)
      ),
      NormalText("Page $displayPage"),
      FButton.icon(
        variant: FButtonVariant.ghost,
        onPress: loaded.hasMore ? () => context.read<ExperimentsBloc>().add(ChangePage(page: nextPage)) : null,
        child: const NormalIcon(Icons.chevron_right)
      )
    ]);
  }
}

class ColumnHeaders extends StatelessWidget {
  const ColumnHeaders({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(children: [
      SizedBox(width: 10.0),
      ListCell(value: "ID", flex: 1, alignLeft: true),
      ListCell(value: "Title", flex: 6),
      ListCell(value: "Status", flex: 3),
      ListCell(value: "Visibility", flex: 2),
      ListCell(value: "Last Updated", flex: 1),
      ListCell(value: "", flex: 2)
    ]);
  }
}

class ExperimentRow extends StatelessWidget {
  final ExperimentSummary summary;

  const ExperimentRow({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final status = summary.status;
    final lastUpdated = relativeTime(summary.lastUpdated);

    return Row(children: [
      const SizedBox(width: 10.0),
      ListCell(value: summary.id, flex: 1, alignLeft: true),
      ListCell(value: summary.title, flex: 6, alignLeft: true),
      StatusIndicator(status: status),
      ListCell(value: summary.isPublic ? "Public" : "Private", flex: 2),
      ListCell(value: lastUpdated, flex: 1),
      Expanded(flex: 2, child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        FButton.icon(
          variant: .ghost,
          onPress: status == ExperimentStatus.completed || status == ExperimentStatus.errored ? () async {
            if (status == ExperimentStatus.completed) {
              Navigator.push(context, MaterialPageRoute(
                builder: (routeContext) => ResultsPage(experimentId: summary.id, title: summary.title)
              ));
            } else {
              late final String? errorMessage;
              try {
                final table = context.read<SupabaseClient>().from("experiments");
                final query = table.select("results");
                final json = await query.eq("id", summary.id).single();
                final results = json["results"];
                errorMessage = results is Map<String, dynamic> ? results["error"] as String? : null;
              } catch (error) {
                if (!context.mounted) return;
                errorDialog(context: context, message: error.toString());
                return;
              }

              if (!context.mounted) return;
              errorDialog(context: context, message: errorMessage ?? "No error message available");
            }
          } : null,
          child: const NormalIcon(Icons.open_in_new)
        ),
        FButton.icon(
          variant: .ghost,
          onPress: () async {
            late final String source;
            try {
              final table = context.read<SupabaseClient>().from("experiments");
              final query = table.select("source");
              final json = await query.eq("id", summary.id).single();
              source = json["source"] as String;
            } catch (error) {
              if (!context.mounted) return;
              errorDialog(context: context, message: error.toString());
              return;
            }

            if (!context.mounted) return;
            final result = await Navigator.push(context, MaterialPageRoute<ExperimentEditorResult?>(
              builder: (routeContext) => EditorPage(source: source, title: "Copy of ${summary.title}")
            ));

            if (!context.mounted || result == null) return;
            final event = QueueExperiment(title: result.title, source: result.source);
            context.read<ExperimentsBloc>().add(event);
          },
          child: const NormalIcon(Icons.content_copy)
        ),
        if (summary.userId == context.read<SupabaseClient>().auth.currentUser!.id)
          FButton.icon(
            variant: .ghost,
            onPress: () async {
              final confirmed = await confirmDeleteDialog(context: context, title: summary.title);
              if (!context.mounted || !confirmed) return;

              final event = DeleteExperiment(id: summary.id);
              context.read<ExperimentsBloc>().add(event);
            },
            child: const NormalIcon(Icons.delete_outline)
          )
      ]))
    ]);
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

Future<String?> openByIdDialog({required BuildContext context}) async {
  final controller = TextEditingController();

  return await showDialogUtil<String>(
    context: context,
    title: "Open Experiment",
    content: StyledTextField(
      controller: controller,
      autofocus: true,
      onSubmitted: (value) => Navigator.pop(context, value)
    ),
    actions: (innerContext) => [
      FButton(
        variant: FButtonVariant.outline,
        onPress: () => Navigator.pop(innerContext),
        child: const NormalText("Cancel")
      ),
      FButton(
        onPress: () => Navigator.pop(innerContext, controller.text),
        child: const InvertedText("Open")
      )
    ]
  );
}
