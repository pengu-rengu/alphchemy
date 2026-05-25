import "package:alphchemy/blocs/experiments/results_bloc.dart";
import "package:alphchemy/widgets/results/results_dashboard.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ResultsContent extends StatelessWidget {
  const ResultsContent({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<ResultsBloc>().state as ResultsLoaded;

    final results = state.results;
    final error = results.error;
    if (error != null) {
      return Center(child: NormalText(error.isInternal ? "Internal error: ${error.error}" : error.error));
    }

    final folds = results.folds;
    if (folds == null) {
      return const Center(child: NormalText("Unsupported results"));
    }

    return ResultsDashboard(
      title: results.title,
      folds: folds,
      experiment: results.experiment,
      selectedFoldIdx: state.selectedFoldIdx
    );
  }
}
