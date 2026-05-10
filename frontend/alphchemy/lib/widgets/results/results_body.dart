import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/widgets/results/results_dashboard.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ResultsBody extends StatelessWidget {
  final String title;

  const ResultsBody({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResultsBloc, ResultsState>(
      builder: (context, state) {
        if (state is ResultsError) {
          return Center(child: Text(state.message));
        }
        if (state is! ResultsLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final results = state.results;
        final error = results.error;
        if (error != null) {
          return Center(child: Text(error.isInternal ? "Internal error: ${error.error}" : error.error));
        }

        final folds = results.folds;
        if (folds == null) {
          return const Center(child: Text("Unsupported results"));
        }

        return ResultsDashboard(
          title: title,
          folds: folds,
          experiment: results.experiment,
          selectedFoldIdx: state.selectedFoldIdx
        );
      }
    );
  }
}