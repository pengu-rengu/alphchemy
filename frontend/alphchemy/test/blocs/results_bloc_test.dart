import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/model/results_data.dart";
import "package:alphchemy/repositories/results_repository.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("loads mock results and selects a fold", () async {
    final bloc = ResultsBloc(repository: ResultsRepository());
    addTearDown(bloc.close);

    final loadedFuture = bloc.stream.firstWhere(_ResultsBlocMatchers.isLoaded);
    bloc.add(const LoadResults());

    final loadedState = await loadedFuture as ResultsLoaded;
    final results = loadedState.record.results as SuccessResults;

    expect(loadedState.selectedFoldIndex, 0);
    expect(results.foldResults.length, 4);

    final selectedFuture = bloc.stream.firstWhere(_ResultsBlocMatchers.isSelectedFoldTwo);
    bloc.add(const SelectFold(foldIndex: 2));

    final selectedState = await selectedFuture as ResultsLoaded;
    expect(selectedState.selectedFoldIndex, 2);
  });
}

class _ResultsBlocMatchers {
  const _ResultsBlocMatchers();

  static bool isLoaded(ResultsState state) {
    return state is ResultsLoaded;
  }

  static bool isSelectedFoldTwo(ResultsState state) {
    if (state is! ResultsLoaded) {
      return false;
    }

    return state.selectedFoldIndex == 2;
  }
}
