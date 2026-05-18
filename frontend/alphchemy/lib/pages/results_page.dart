import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/widgets/results/results_body.dart";
import "package:alphchemy/widgets/results/results_dashboard.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ResultsPage extends StatelessWidget {
  final int? experimentId;

  const ResultsPage({
    super.key,
    this.experimentId
  });

  @override
  Widget build(BuildContext context) {
    final client = context.read<SupabaseClient>();

    return BlocProvider(
      create: (blocContext) {
        final bloc = ResultsBloc(client: client);
        final id = experimentId;
        if (id != null) {
          final event = LoadResults(experimentId: id);
          bloc.add(event);
        }
        return bloc;
      },
      child: const Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              ResultsHeader(),
              Divider(height: 1),
              Expanded(child: ResultsBody())
            ]
          )
        )
      )
    );
  }
}

class ResultsHeader extends StatelessWidget {
  const ResultsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        children: [
          IconButton(
            icon: const NormalIcon(Icons.arrow_back),
            tooltip: "Back",
            onPressed: () => Navigator.of(context).pop()
          ),
          const SizedBox(width: 10.0),
          const LargeText("Results"),
          const Spacer(),
          BlocBuilder<ResultsBloc, ResultsState>(
            builder: (context, state) {
              if (state is! ResultsLoaded) {
                return const SizedBox();
              }
              return ExperimentConfigButton(experiment: state.results.experiment);
            }
          )
        ]
      )
    );
  }
}
