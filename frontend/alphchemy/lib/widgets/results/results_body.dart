import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/model/results_data.dart";
import "package:alphchemy/widgets/results/results_dashboard.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ResultsBody extends StatelessWidget {
  const ResultsBody({super.key});

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

        final record = state.record;
        final error = record.error;
        if (error != null) {
          return ResultsFailureView(results: error);
        }

        final folds = record.folds;
        if (folds == null) {
          return const Center(child: Text("Unsupported results"));
        }

        return ResultsDashboard(
          folds: folds,
          selectedFoldIndex: state.selectedFoldIndex
        );
      }
    );
  }
}

class ResultsFailureView extends StatelessWidget {
  final ErrorResults results;

  const ResultsFailureView({
    super.key,
    required this.results
  });

  @override
  Widget build(BuildContext context) {
    final message = results.isInternal
        ? "Internal error: ${results.error}"
        : results.error;

    return Center(child: Text(message));
  }
}
