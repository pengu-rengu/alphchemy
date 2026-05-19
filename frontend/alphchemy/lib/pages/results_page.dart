import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/widgets/results/results_area.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/results/results_dashboard.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ResultsPage extends StatelessWidget {
  final String title;
  final int experimentId;

  const ResultsPage({super.key, required this.experimentId, required this.title});

  @override
  Widget build(BuildContext context) {
    final client = context.read<SupabaseClient>();

    return BlocProvider(
      create: (blocContext) {
        final bloc = ResultsBloc(client: client);
        final event = LoadResults(experimentId: experimentId);
        bloc.add(event);
        return bloc;
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              ResultsHeader(title: title),
              const Divider(height: 1),
              const Expanded(child: ResultsArea())
            ]
          )
        )
      )
    );
  }
}

class ResultsHeader extends StatelessWidget {
  final String title;

  const ResultsHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Header(
      left: [
        IconButton(
          icon: const NormalIcon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop()
        ),
        const SizedBox(width: 10.0),
        LargeText(title)
      ],
      right: [
        BlocBuilder<ResultsBloc, ResultsState>(
          builder: (context, state) {
            if (state is ResultsLoaded) {
              return ExperimentConfigButton(experiment: state.results.experiment);
            }
            return const SizedBox();
          }
        )
      ]
    );
  }
}
