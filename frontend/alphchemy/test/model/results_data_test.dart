import "package:alphchemy/model/results.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("parses successful results", () {
    final json = {
      "results": [
        {
          "start_idx": 10,
          "end_idx": 20,
          "opt_results": {
            "iters": 12,
            "best_seq": ["set_feat", "set_threshold"],
            "train_improvements": [
              {
                "iter": 1,
                "score": 0.1
              }
            ],
            "val_improvements": [
              {
                "iter": 2,
                "score": 0.2
              }
            ]
          },
          "train_results": _ResultsTestData.backtestJson(false, 0.3),
          "val_results": _ResultsTestData.backtestJson(false, 0.2),
          "test_results": _ResultsTestData.backtestJson(true, 0.0)
        }
      ]
    };

    final record = ExperimentResults.fromJson(json);
    final folds = record.folds!;
    final fold = folds.first;

    expect(record.error, isNull);
    expect(folds.length, 1);
    expect(fold.startIdx, 10);
    expect(fold.optResults.bestSeq, ["set_feat", "set_threshold"]);
    expect(fold.testResults.isInvalid, true);
  });

  test("parses validation error results", () {
    final json = {
      "results": {
        "error": "cv_folds must be > 0",
        "is_internal": false
      }
    };

    final record = ExperimentResults.fromJson(json);

    expect(record.folds, isNull);
    final error = record.error!;
    expect(error.error, "cv_folds must be > 0");
    expect(error.isInternal, false);
  });

  test("rejects nullable best sequence entries", () {
    final json = {
      "iters": 12,
      "best_seq": ["set_feat", null],
      "train_improvements": <Map<String, dynamic>>[],
      "val_improvements": <Map<String, dynamic>>[]
    };

    expect(
      () {
        OptimizerResults.fromJson(json);
      },
      throwsA(isA<TypeError>())
    );
  });
}

class _ResultsTestData {
  const _ResultsTestData();

  static Map<String, dynamic> backtestJson(bool isInvalid, double excessSharpe) {
    return {
      "is_invalid": isInvalid,
      "excess_sharpe": excessSharpe,
      "mean_hold_time": 3.0,
      "std_hold_time": 1.0,
      "entries": 4,
      "total_exits": 3,
      "signal_exits": 1,
      "stop_loss_exits": 1,
      "take_profit_exits": 1,
      "max_hold_exits": 0
    };
  }
}
