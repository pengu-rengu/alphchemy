import "package:alphchemy/model/results_data.dart";

class ResultsRepository {
  Future<ExperimentResultsRecord> load() async {
    return _mockRecord();
  }

  ExperimentResultsRecord _mockRecord() {
    final folds = <FoldResults>[
      _mockFold(
        startIdx: 0,
        endIdx: 1499,
        iters: 42,
        trainScores: const [-0.04, 0.05, 0.13, 0.24],
        valScores: const [-0.03, 0.04, 0.09, 0.18],
        trainResults: _mockBacktestResults(
          isInvalid: false,
          excessSharpe: 0.31,
          meanHoldTime: 18.2,
          stdHoldTime: 5.4,
          entries: 42,
          totalExits: 39,
          signalExits: 17,
          stopLossExits: 9,
          takeProfitExits: 10,
          maxHoldExits: 3
        ),
        valResults: _mockBacktestResults(
          isInvalid: false,
          excessSharpe: 0.22,
          meanHoldTime: 15.8,
          stdHoldTime: 4.7,
          entries: 18,
          totalExits: 17,
          signalExits: 7,
          stopLossExits: 4,
          takeProfitExits: 5,
          maxHoldExits: 1
        ),
        testResults: _mockBacktestResults(
          isInvalid: false,
          excessSharpe: 0.18,
          meanHoldTime: 14.4,
          stdHoldTime: 4.2,
          entries: 12,
          totalExits: 11,
          signalExits: 5,
          stopLossExits: 2,
          takeProfitExits: 3,
          maxHoldExits: 1
        )
      ),
      _mockFold(
        startIdx: 1500,
        endIdx: 2999,
        iters: 58,
        trainScores: const [-0.02, 0.07, 0.16, 0.29],
        valScores: const [-0.01, 0.03, 0.11, 0.16],
        trainResults: _mockBacktestResults(
          isInvalid: false,
          excessSharpe: 0.37,
          meanHoldTime: 21.0,
          stdHoldTime: 7.1,
          entries: 49,
          totalExits: 45,
          signalExits: 19,
          stopLossExits: 11,
          takeProfitExits: 12,
          maxHoldExits: 3
        ),
        valResults: _mockBacktestResults(
          isInvalid: false,
          excessSharpe: 0.19,
          meanHoldTime: 18.5,
          stdHoldTime: 5.2,
          entries: 21,
          totalExits: 20,
          signalExits: 8,
          stopLossExits: 5,
          takeProfitExits: 5,
          maxHoldExits: 2
        ),
        testResults: _mockBacktestResults(
          isInvalid: false,
          excessSharpe: 0.11,
          meanHoldTime: 17.2,
          stdHoldTime: 4.9,
          entries: 14,
          totalExits: 13,
          signalExits: 5,
          stopLossExits: 4,
          takeProfitExits: 3,
          maxHoldExits: 1
        )
      ),
      _mockFold(
        startIdx: 3000,
        endIdx: 4499,
        iters: 31,
        trainScores: const [-0.05, 0.02, 0.10],
        valScores: const [-0.04, 0.01, 0.05],
        trainResults: _mockBacktestResults(
          isInvalid: false,
          excessSharpe: 0.14,
          meanHoldTime: 13.7,
          stdHoldTime: 3.8,
          entries: 27,
          totalExits: 24,
          signalExits: 10,
          stopLossExits: 6,
          takeProfitExits: 6,
          maxHoldExits: 2
        ),
        valResults: _mockBacktestResults(
          isInvalid: false,
          excessSharpe: 0.06,
          meanHoldTime: 12.9,
          stdHoldTime: 3.1,
          entries: 11,
          totalExits: 10,
          signalExits: 4,
          stopLossExits: 3,
          takeProfitExits: 2,
          maxHoldExits: 1
        ),
        testResults: _mockBacktestResults(
          isInvalid: true,
          excessSharpe: 0.0,
          meanHoldTime: 0.0,
          stdHoldTime: 0.0,
          entries: 5,
          totalExits: 0,
          signalExits: 0,
          stopLossExits: 0,
          takeProfitExits: 0,
          maxHoldExits: 0
        )
      ),
      _mockFold(
        startIdx: 4500,
        endIdx: 5999,
        iters: 64,
        trainScores: const [-0.03, 0.08, 0.21, 0.34],
        valScores: const [-0.02, 0.06, 0.14, 0.23],
        trainResults: _mockBacktestResults(
          isInvalid: false,
          excessSharpe: 0.42,
          meanHoldTime: 19.4,
          stdHoldTime: 6.0,
          entries: 54,
          totalExits: 52,
          signalExits: 20,
          stopLossExits: 12,
          takeProfitExits: 16,
          maxHoldExits: 4
        ),
        valResults: _mockBacktestResults(
          isInvalid: false,
          excessSharpe: 0.27,
          meanHoldTime: 16.8,
          stdHoldTime: 4.6,
          entries: 24,
          totalExits: 22,
          signalExits: 9,
          stopLossExits: 5,
          takeProfitExits: 7,
          maxHoldExits: 1
        ),
        testResults: _mockBacktestResults(
          isInvalid: false,
          excessSharpe: 0.24,
          meanHoldTime: 15.9,
          stdHoldTime: 4.4,
          entries: 16,
          totalExits: 15,
          signalExits: 6,
          stopLossExits: 3,
          takeProfitExits: 5,
          maxHoldExits: 1
        )
      )
    ];

    final success = SuccessResults(
      overallExcessSharpe: 0.1767,
      invalidFrac: 0.25,
      foldResults: folds
    );

    return ExperimentResultsRecord(
      title: "Mock Mean Reversion",
      results: success
    );
  }

  FoldResults _mockFold({
    required int startIdx,
    required int endIdx,
    required int iters,
    required List<double> trainScores,
    required List<double> valScores,
    required BacktestResults trainResults,
    required BacktestResults valResults,
    required BacktestResults testResults
  }) {
    final optResults = _mockOptResults(
      iters: iters,
      trainScores: trainScores,
      valScores: valScores
    );

    return FoldResults(
      startIdx: startIdx,
      endIdx: endIdx,
      optResults: optResults,
      trainResults: trainResults,
      valResults: valResults,
      testResults: testResults
    );
  }

  OptimizerResults _mockOptResults({
    required int iters,
    required List<double> trainScores,
    required List<double> valScores
  }) {
    final trainImprovements = _mockImprovements(trainScores);
    final valImprovements = _mockImprovements(valScores);

    return OptimizerResults(
      iters: iters,
      bestSeq: const ["set_feat", "set_threshold", "select_node", "set_gate", "set_in1_idx"],
      trainImprovements: trainImprovements,
      valImprovements: valImprovements
    );
  }

  List<Improvement> _mockImprovements(List<double> scores) {
    final improvements = <Improvement>[];

    for (var index = 0; index < scores.length; index += 1) {
      final iter = (index + 1) * 10;
      final score = scores[index];
      final improvement = Improvement(iter: iter, score: score);
      improvements.add(improvement);
    }

    return improvements;
  }

  BacktestResults _mockBacktestResults({
    required bool isInvalid,
    required double excessSharpe,
    required double meanHoldTime,
    required double stdHoldTime,
    required int entries,
    required int totalExits,
    required int signalExits,
    required int stopLossExits,
    required int takeProfitExits,
    required int maxHoldExits
  }) {
    return BacktestResults(
      isInvalid: isInvalid,
      excessSharpe: excessSharpe,
      meanHoldTime: meanHoldTime,
      stdHoldTime: stdHoldTime,
      entries: entries,
      totalExits: totalExits,
      signalExits: signalExits,
      stopLossExits: stopLossExits,
      takeProfitExits: takeProfitExits,
      maxHoldExits: maxHoldExits
    );
  }
}
