import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/widgets/results/results_dashboard.dart";
import "package:alphchemy/widgets/widget_utils.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ResultsBody extends StatelessWidget {
  const ResultsBody({super.key});

  @override
  Widget build(BuildContext context) {
    
    return BlocBuilder<ResultsBloc, ResultsState>(
      builder: (context, state) {
        if (state is ResultsError) {
          return Center(child: NormalText(state.message));
        }
        if (state is ResultsInitial) {
          return const Center(child: NormalText("Enter an experiment id to open results"));
        }
        if (state is! ResultsLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

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
    );
  }
}
