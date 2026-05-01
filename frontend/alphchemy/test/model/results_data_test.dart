import "package:alphchemy/model/results_data.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("parses successful results", () {
    final json = {
      "experiment": {
        "title": "sample"
      },
      "results": {
        "overall_excess_sharpe": 0.25,
        "invalid_frac": 0.5,
        "fold_results": [
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
      }
    };

    final record = ExperimentResultsRecord.fromJson(json);
    final results = record.results as SuccessResults;
    final fold = results.foldResults.first;

    expect(record.title, "sample");
    expect(results.overallExcessSharpe, 0.25);
    expect(results.invalidFrac, 0.5);
    expect(fold.startIdx, 10);
    expect(fold.optResults.bestSeq, ["set_feat", "set_threshold"]);
    expect(fold.testResults.isInvalid, true);
  });

  test("parses validation error results", () {
    final json = {
      "error": "cv_folds must be > 0",
      "is_internal": false
    };

    final results = ResultsPayload.fromJson(json);

    expect(results, isA<ErrorResults>());
    final errorResults = results as ErrorResults;
    expect(errorResults.error, "cv_folds must be > 0");
    expect(errorResults.isInternal, false);
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
