import "package:alphchemy/model/results.dart";
import "package:alphchemy/widgets/results/results_charts.dart";
import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

BacktestResults _backtestResults() {
  return const BacktestResults(
    isInvalid: false,
    excessSharpe: 0.0,
    meanHoldTime: 0.0,
    stdHoldTime: 0.0,
    entries: 0,
    totalExits: 0,
    signalExits: 0,
    stopLossExits: 0,
    takeProfitExits: 0,
    maxHoldExits: 0
  );
}

FoldResults _foldWithScores(double trainScore, double valScore) {
  final trainImprovement = Improvement(iter: 1, score: trainScore);
  final valImprovement = Improvement(iter: 3, score: valScore);
  final trainImprovements = [trainImprovement];
  final valImprovements = [valImprovement];
  final bestSeq = <String>[];
  final optResults = OptimizerResults(
    iters: 4,
    bestSeq: bestSeq,
    trainImprovements: trainImprovements,
    valImprovements: valImprovements
  );
  final backtestResults = _backtestResults();

  return FoldResults(
    startIdx: 0,
    endIdx: 10,
    optResults: optResults,
    trainResults: backtestResults,
    valResults: backtestResults,
    testResults: backtestResults
  );
}

Future<void> _pumpChart(
  WidgetTester tester,
  FoldResults fold
) async {
  final optimizerChart = OptimizerChart(fold: fold);
  const chartSize = Size(600, 320);
  final chartBox = SizedBox.fromSize(
    size: chartSize,
    child: optimizerChart
  );
  final scaffold = Scaffold(body: chartBox);
  final app = MaterialApp(home: scaffold);

  await tester.pumpWidget(app);
}

void main() {
  testWidgets("scales optimizer chart to small scores", (WidgetTester tester) async {
    final fold = _foldWithScores(0.002, 0.003);
    await _pumpChart(tester, fold);

    final chartFinder = find.byType(LineChart);
    final chart = tester.widget<LineChart>(chartFinder);
    final maxMatcher = closeTo(0.0036, 0.0000001);

    expect(chart.data.minY, 0.0);
    expect(chart.data.maxY, maxMatcher);
  });
}
