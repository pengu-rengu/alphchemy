import "package:alphchemy/blocs/results_bloc.dart";
import "package:flutter_test/flutter_test.dart";

import "../helpers/supabase_test_server.dart";

void main() {
  test("loads results by experiment id and selects a fold", () async {
    final response = SupabaseTestResponse(body: {
      "results": _foldsJson(3)
    });
    final server = await SupabaseTestServer.start([response]);
    final client = server.createClient();
    final bloc = ResultsBloc(client: client);
    addTearDown(bloc.close);
    addTearDown(client.dispose);
    addTearDown(server.close);

    final loadedFuture = bloc.stream.firstWhere(_ResultsBlocMatchers.isLoaded);
    bloc.add(const LoadResults(experimentId: 42));

    final loadedState = await loadedFuture as ResultsLoaded;
    final folds = loadedState.record.folds!;
    final request = server.requests.first;

    expect(request.method, "GET");
    expect(request.path, "/rest/v1/experiments");
    expect(request.query["id"], "eq.42");
    expect(request.query["select"], "results");
    expect(loadedState.selectedFoldIndex, 0);
    expect(folds.length, 3);

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

List<Map<String, dynamic>> _foldsJson(int foldCount) {
  final folds = <Map<String, dynamic>>[];

  for (var index = 0; index < foldCount; index += 1) {
    final fold = _foldJson(index);
    folds.add(fold);
  }

  return folds;
}

Map<String, dynamic> _foldJson(int index) {
  final startIdx = index * 10;
  final endIdx = startIdx + 9;
  final optResults = <String, dynamic>{
    "iters": 1,
    "best_seq": <String>[],
    "train_improvements": <Map<String, dynamic>>[],
    "val_improvements": <Map<String, dynamic>>[]
  };
  final backtestResults = _backtestResultsJson();

  return {
    "start_idx": startIdx,
    "end_idx": endIdx,
    "opt_results": optResults,
    "train_results": backtestResults,
    "val_results": backtestResults,
    "test_results": backtestResults
  };
}

Map<String, dynamic> _backtestResultsJson() {
  return {
    "is_invalid": false,
    "excess_sharpe": 0,
    "mean_hold_time": 0,
    "std_hold_time": 0,
    "entries": 0,
    "total_exits": 0,
    "signal_exits": 0,
    "stop_loss_exits": 0,
    "take_profit_exits": 0,
    "max_hold_exits": 0
  };
}
