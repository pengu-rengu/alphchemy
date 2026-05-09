import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/widgets/results/results_body.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ResultsPage extends StatelessWidget {
  final int experimentId;
  final String title;

  const ResultsPage({
    super.key,
    required this.experimentId,
    required this.title
  });

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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: "Back",
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.pop();
            }
          ),
          title: const Text("Results")
        ),
        body: ResultsBody(title: title)
      )
    );
  }
}
