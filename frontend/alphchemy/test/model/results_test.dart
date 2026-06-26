import "dart:convert";

import "package:alphchemy/model/results.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("results parser uses train and val sequences and networks", () {
    final trainNet = <String, dynamic>{
      "nodes": <dynamic>[],
      "default_value": false
    };
    final valNet = <String, dynamic>{
      "nodes": <dynamic>[],
      "default_value": true
    };
    final optResultsJson = _optResults(
      bestTrainSeq: <dynamic>["train"],
      bestTrainNet: trainNet,
      bestValSeq: <dynamic>["val"],
      bestValNet: valNet
    );
    final row = _experimentRow(optResultsJson);
    final results = ExperimentResults.fromJson(row);
    final fold = results.folds.single;
    final optResults = fold.optResults;
    const encoder = JsonEncoder.withIndent("  ");

    expect(optResults.bestTrainSeq, ["train"]);
    expect(optResults.bestTrainNet, encoder.convert(trainNet));
    expect(optResults.bestValSeq, ["val"]);
    expect(optResults.bestValNet, encoder.convert(valNet));
  });

  test("optimizer results formats networks as pretty json", () {
    final value = <String, dynamic>{
      "nodes": <dynamic>[
        <String, dynamic>{
          "type": "input",
          "threshold": 0.2,
          "feat_id": "close"
        }
      ],
      "default_value": false
    };
    const encoder = JsonEncoder.withIndent("  ");

    expect(OptimizerResults.formatNet(value), encoder.convert(value));
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
    "start_timestamp": "1",
    "end_timestamp": "2",
    "train_start_timestamp": "1",
    "train_end_timestamp": "2",
    "val_start_timestamp": "2",
    "val_end_timestamp": "3",
    "test_start_timestamp": "3",
    "test_end_timestamp": "4",
    "opt_results": optResults,
    "train_results": trainResults,
    "val_results": valResults,
    "test_results": testResults
  };
}

Map<String, dynamic> _optResults({
  required List<dynamic> bestTrainSeq,
  required Map<String, dynamic> bestTrainNet,
  required List<dynamic> bestValSeq,
  required Map<String, dynamic> bestValNet
}) {
  final trainImprovements = <Map<String, dynamic>>[];
  final valImprovements = <Map<String, dynamic>>[];
  final json = <String, dynamic>{
    "iters": 1,
    "best_train_seq": bestTrainSeq,
    "best_train_net": bestTrainNet,
    "best_val_seq": bestValSeq,
    "best_val_net": bestValNet,
    "train_improvements": trainImprovements,
    "val_improvements": valImprovements
  };

  return json;
}

Map<String, dynamic> _backtestResults() {
  return {
    "is_invalid": false,
    "metrics": {"excess_sharpe": 1.0},
    "equity_curve": <dynamic>[100.0, 101.0]
  };
}
