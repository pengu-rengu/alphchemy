import "package:alphchemy/blocs/experiments/experiments_bloc.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/model/experiment/experiment.dart";
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
            const ExperimentsHeader(),
            const Divider(height: 1),
            switch (state) {
              ExperimentsInitial() => const Expanded(child: Center(child: CircularProgressIndicator())),
              ExperimentsError() => Expanded(child: CenterText(state.message)),
              // ignore: prefer_const_constructors
              ExperimentsLoaded() => ExperimentsList()
            }
          ]
        );
      }
    );
  }
}

class ExperimentsList extends StatelessWidget {
  const ExperimentsList({super.key});

  @override
  Widget build(BuildContext context) {
    final experiments = (context.read<ExperimentsBloc>().state as ExperimentsLoaded).experiments;

    return Expanded(
      child: experiments.isEmpty ? const CenterText("No experiments yet") : ListView.builder(
        padding: const EdgeInsets.all(10.0),
        itemCount: experiments.length,
        itemBuilder: (context, idx) {
          return ExperimentCard(summary: experiments[idx]);
        }
      )
    );
  }
}

class ExperimentsHeader extends StatelessWidget {
  const ExperimentsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Header(
      left: const [LargeText("Experiments")], 
      right: [FilledButton.icon(
        onPressed: () async {
          final result = await Navigator.push<ExperimentEditorResult?>(context, MaterialPageRoute(
            builder: (routeContext) => const EditorPage()
          ));
          if (!context.mounted || result == null) {
            return;
          }

          final event = QueueExperiment(title: result.title, experiment: result.experiment);
          context.read<ExperimentsBloc>().add(event);
        },
        icon: const InvertedIcon(Icons.add),
        label: const InvertedText("Queue Experiment")
      )]
    );
  }
}

class ExperimentCard extends StatelessWidget {
  final ExperimentSummary summary;

  const ExperimentCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final status = summary.status;

    return PaddedCard(child: Row(
      children: [
        NormalText(summary.title),
        const SizedBox(width: 10.0),
        NormalText(status.name),
        const Spacer(),
        IconButton(
          onPressed: () {
            if (status == ExperimentStatus.completed) {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (routeContext) => ResultsPage(
                  experimentId: summary.id,
                  title: summary.title,
                )
              ));
            } else if (status == ExperimentStatus.errored) {
              errorDialog(context: context, message: summary.errorMessage ?? "No error message available");
            }
          },
          icon: const NormalIcon(Icons.open_in_new)
        ),
        IconButton(
          icon: const NormalIcon(Icons.content_copy),
          onPressed: () async {
            late final Experiment experiment;

            try {
              final table = context.read<SupabaseClient>().from("experiments");
              final query = table.select("experiment");
              final json = await query.eq("id", summary.id).single();
              experiment = Experiment.fromJson(json["experiment"] as Map<String, dynamic>);
            } catch (error) {
              if (!context.mounted) {
                return;
              }

              errorDialog(context: context, message: error.toString());
              return;
            }
            
            if (!context.mounted) {
              return;
            }
            final result = await Navigator.push(context, MaterialPageRoute<ExperimentEditorResult?>(
              builder: (routeContext) => EditorPage(
                experiment: experiment,
                title: "Copy of ${summary.title}"
              )
            ));
            
            if (!context.mounted || result == null) {
              return;
            }

            final event = QueueExperiment(title: result.title, experiment: result.experiment);
            context.read<ExperimentsBloc>().add(event);
          }
        ),
        IconButton(
          icon: const NormalIcon(Icons.delete_outline),
          onPressed: () async {
            final confirmed = await confirmDeleteDialog(context: context, title: summary.title);
            if (!context.mounted || !confirmed) {
              return;
            }

            final event = DeleteExperiment(id: summary.id);
            context.read<ExperimentsBloc>().add(event);
          }
        )
      ]
    ));
  }
}
