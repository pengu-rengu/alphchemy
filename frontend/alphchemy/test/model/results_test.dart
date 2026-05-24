import "package:alphchemy/model/results.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("results parser uses train and val sequences", () {
    final optResultsJson = _optResults(
      bestTrainSeq: ["train"],
      bestValSeq: ["val"]
    );
    final row = _experimentRow(optResultsJson);
    final results = ExperimentResults.fromJson(row);
    final fold = results.folds!.single;
    final optResults = fold.optResults;

    expect(optResults.bestTrainSeq, ["train"]);
    expect(optResults.bestValSeq, ["val"]);
  });

  test("results parser falls back to legacy sequence", () {
    final optResultsJson = _optResults(bestSeq: ["legacy"]);
    final row = _experimentRow(optResultsJson);
    final results = ExperimentResults.fromJson(row);
    final fold = results.folds!.single;
    final optResults = fold.optResults;

    expect(optResults.bestTrainSeq, ["legacy"]);
    expect(optResults.bestValSeq, ["legacy"]);
  });

  test("results parser handles missing sequence fields", () {
    final optResultsJson = _optResults();
    final row = _experimentRow(optResultsJson);
    final results = ExperimentResults.fromJson(row);
    final fold = results.folds!.single;
    final optResults = fold.optResults;

    expect(optResults.bestTrainSeq, <String>[]);
    expect(optResults.bestValSeq, <String>[]);
  });
}

Map<String, dynamic> _experimentRow(Map<String, dynamic> optResults) {
  final foldResults = _foldResults(optResults);

  return {
    "title": "Mock Experiment",
    "experiment": null,
    "results": [foldResults]
  };
}

Map<String, dynamic> _foldResults(Map<String, dynamic> optResults) {
  final trainResults = _backtestResults();
  final valResults = _backtestResults();
  final testResults = _backtestResults();

  return {
    "start_timestamp": 1.0,
    "end_timestamp": 2.0,
    "train_start_timestamp": 1.0,
    "train_end_timestamp": 2.0,
    "val_start_timestamp": 2.0,
    "val_end_timestamp": 3.0,
    "test_start_timestamp": 3.0,
    "test_end_timestamp": 4.0,
    "opt_results": optResults,
    "train_results": trainResults,
    "val_results": valResults,
    "test_results": testResults
  };
}

Map<String, dynamic> _optResults({
  List<String>? bestSeq,
  List<String>? bestTrainSeq,
  List<String>? bestValSeq
}) {
  final trainImprovements = <Map<String, dynamic>>[];
  final valImprovements = <Map<String, dynamic>>[];
  final json = <String, dynamic>{
    "iters": 1,
    "train_improvements": trainImprovements,
    "val_improvements": valImprovements
  };

  if (bestSeq != null) {
    json["best_seq"] = bestSeq;
  }

  if (bestTrainSeq != null) {
    json["best_train_seq"] = bestTrainSeq;
  }

  if (bestValSeq != null) {
    json["best_val_seq"] = bestValSeq;
  }

  return json;
}

Map<String, dynamic> _backtestResults() {
  return {
    "is_invalid": false,
    "excess_sharpe": 1.0,
    "mean_hold_time": 2.0,
    "std_hold_time": 3.0,
    "entries": 4,
    "total_exits": 5,
    "signal_exits": 1,
    "stop_loss_exits": 1,
    "take_profit_exits": 1,
    "max_hold_exits": 2
  };
}
