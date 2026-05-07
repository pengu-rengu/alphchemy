import "package:alphchemy/model/results_data.dart";
import "package:alphchemy/widgets/results/results_chart_shell.dart";
import "package:alphchemy/widgets/results/results_dashboard.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("shows requested charts and table metrics", (WidgetTester tester) async {
    final folds = _ResultsDashboardData.folds();

    await _pumpDashboard(tester, folds);

    expect(find.byType(ChartPanel), findsNWidgets(3));
    expect(find.byType(ResultsTablePanel), findsNWidgets(2));
    expect(find.text("Excess Sharpe"), findsOneWidget);
    expect(find.text("Optimizer Improvements"), findsOneWidget);
    expect(find.text("Exit Reasons"), findsOneWidget);
    expect(find.text("Entries and Exits"), findsNothing);
    expect(find.text("Hold Time"), findsNothing);

    expect(find.text("Fold and Optimizer"), findsOneWidget);
    expect(find.text("Backtest Metrics"), findsOneWidget);
    expect(find.text("Folds"), findsOneWidget);
    expect(find.text("Selected Range"), findsOneWidget);
    expect(find.text("Optimizer Iters"), findsOneWidget);
    expect(find.text("Best Sequence"), findsOneWidget);
    expect(find.text("Train Improvement Count"), findsOneWidget);
    expect(find.text("Val Improvement Count"), findsOneWidget);
    expect(find.text("2"), findsWidgets);
    expect(find.text("0-99"), findsOneWidget);
    expect(find.text("20"), findsOneWidget);
    expect(find.text("set_feat -> set_threshold"), findsOneWidget);

    expect(find.text("Validity"), findsOneWidget);
    expect(find.text("Mean Hold Time"), findsOneWidget);
    expect(find.text("Std Hold Time"), findsOneWidget);
    expect(find.text("Entries"), findsOneWidget);
    expect(find.text("Total Exits"), findsOneWidget);
    expect(find.text("Train"), findsWidgets);
    expect(find.text("Val"), findsWidgets);
    expect(find.text("Test"), findsWidgets);
    expect(find.text("Valid"), findsNWidgets(3));
    expect(find.text("12.50"), findsOneWidget);
    expect(find.text("2.50"), findsOneWidget);
    expect(find.text("9"), findsOneWidget);
    expect(find.text("8"), findsOneWidget);
  });

  testWidgets("places excess sharpe before fold selector", (WidgetTester tester) async {
    final folds = _ResultsDashboardData.folds();

    await _pumpDashboard(tester, folds);

    final sharpeTop = tester.getTopLeft(find.text("Excess Sharpe")).dy;
    final foldTop = tester.getTopLeft(find.text("Fold 1")).dy;

    expect(sharpeTop, lessThan(foldTop));
  });
}

Future<void> _pumpDashboard(WidgetTester tester, List<FoldResults> folds) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1400));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  final dashboard = ResultsDashboard(
    folds: folds,
    selectedFoldIndex: 0
  );

  final shell = MaterialApp(
    home: Scaffold(
      body: dashboard
    )
  );

  await tester.pumpWidget(shell);
}

class _ResultsDashboardData {
  const _ResultsDashboardData();

  static List<FoldResults> folds() {
    final folds = <FoldResults>[];
    final firstFold = _fold(
      startIdx: 0,
      endIdx: 99,
      iters: 20,
      trainResults: _backtest(
        excessSharpe: 0.30,
        meanHoldTime: 12.5,
        stdHoldTime: 2.5,
        entries: 9,
        totalExits: 8,
        signalExits: 4,
        stopLossExits: 1,
        takeProfitExits: 2,
        maxHoldExits: 1
      ),
      valResults: _backtest(
        excessSharpe: 0.20,
        meanHoldTime: 10.0,
        stdHoldTime: 2.0,
        entries: 7,
        totalExits: 6,
        signalExits: 3,
        stopLossExits: 1,
        takeProfitExits: 1,
        maxHoldExits: 1
      ),
      testResults: _backtest(
        excessSharpe: 0.10,
        meanHoldTime: 8.0,
        stdHoldTime: 1.5,
        entries: 5,
        totalExits: 4,
        signalExits: 2,
        stopLossExits: 1,
        takeProfitExits: 1,
        maxHoldExits: 0
      )
    );
    final secondFold = _fold(
      startIdx: 100,
      endIdx: 199,
      iters: 30,
      trainResults: _backtest(
        excessSharpe: 0.35,
        meanHoldTime: 13.0,
        stdHoldTime: 3.0,
        entries: 10,
        totalExits: 9,
        signalExits: 5,
        stopLossExits: 1,
        takeProfitExits: 2,
        maxHoldExits: 1
      ),
      valResults: _backtest(
        excessSharpe: 0.25,
        meanHoldTime: 11.0,
        stdHoldTime: 2.2,
        entries: 8,
        totalExits: 7,
        signalExits: 3,
        stopLossExits: 1,
        takeProfitExits: 2,
        maxHoldExits: 1
      ),
      testResults: _backtest(
        excessSharpe: 0.15,
        meanHoldTime: 9.0,
        stdHoldTime: 1.7,
        entries: 6,
        totalExits: 5,
        signalExits: 2,
        stopLossExits: 1,
        takeProfitExits: 1,
        maxHoldExits: 1
      )
    );

    folds.add(firstFold);
    folds.add(secondFold);

    return folds;
  }

  static FoldResults _fold({
    required int startIdx,
    required int endIdx,
    required int iters,
    required BacktestResults trainResults,
    required BacktestResults valResults,
    required BacktestResults testResults
  }) {
    final optResults = _optimizer(iters);

    return FoldResults(
      startIdx: startIdx,
      endIdx: endIdx,
      optResults: optResults,
      trainResults: trainResults,
      valResults: valResults,
      testResults: testResults
    );
  }

  static OptimizerResults _optimizer(int iters) {
    const bestSeq = ["set_feat", "set_threshold"];
    const trainImprovements = [
      Improvement(iter: 1, score: 0.1),
      Improvement(iter: 2, score: 0.2)
    ];
    const valImprovements = [
      Improvement(iter: 1, score: 0.05)
    ];

    return OptimizerResults(
      iters: iters,
      bestSeq: bestSeq,
      trainImprovements: trainImprovements,
      valImprovements: valImprovements
    );
  }

  static BacktestResults _backtest({
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
      isInvalid: false,
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
