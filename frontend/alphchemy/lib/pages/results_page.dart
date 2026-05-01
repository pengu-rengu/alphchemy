import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/repositories/results_repository.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:alphchemy/widgets/results/results_body.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ResultsRepository>();

    return BlocProvider(
      create: (_) {
        final bloc = ResultsBloc(repository: repository);
        bloc.add(const LoadResults());
        return bloc;
      },
      child: const PageScaffold(
        selectedIdx: 2,
        child: ResultsBody()
      )
    );
  }
}
