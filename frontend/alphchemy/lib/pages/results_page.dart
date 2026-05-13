import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/widgets/results/results_body.dart";
import "package:alphchemy/widgets/widget_utils.dart";
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
        body: SafeArea(
          child: Column(
            children: [
              const ResultsHeader(),
              const Divider(height: 1),
              Expanded(child: ResultsBody(title: title))
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
            onPressed: () => _back(context)
          ),
          const SizedBox(width: 10),
          const LargeText("Results")
        ]
      )
    );
  }

  void _back(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop();
  }
}
