import "dart:math";

import "package:alphchemy/model/results.dart";
import "package:alphchemy/widgets/chart_utils.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";

class ChartColors {
  static const train = Colors.blue;
  static const val = Colors.amber;
  static const test = Colors.green;
  static const signal = Colors.cyan;
  static const stopLoss = Colors.red;
  static const takeProfit = Colors.purple;
  static const maxHold = Colors.orange;

  const ChartColors();
}

BarChartRodData _rod(double value, Color color) {
  return BarChartRodData(
    toY: value,
    color: color,
    width: 10,
    borderRadius: BorderRadius.zero
  );
}


class ChartLegend extends StatelessWidget {
  final List<String> labels;
  final List<Color> colors;

  const ChartLegend({super.key, required this.labels, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, color: colors[i]),
              const SizedBox(width: 5.0),
              NormalText(labels[i])
            ]
          )
      ]
    );
  }
}

class ChartPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const ChartPanel({
    super.key,
    required this.title,
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    return PaddedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LargeText(title),
          const SizedBox(height: 5),
          SizedBox(height: 250, child: child)
        ]
      )
    );
  }
}

class SharpeChart extends StatelessWidget {
  final List<FoldResults> folds;

  const SharpeChart({super.key, required this.folds});

  @override
  Widget build(BuildContext context) {
    final values = <double>[];

    for (final fold in folds) {
      values.add(fold.trainResults.excessSharpe);
      values.add(fold.valResults.excessSharpe);
      values.add(fold.testResults.excessSharpe);
    }

    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    final minY = min(minValue, 0.0);
    final maxY = max(maxValue, 0.0);
    final barGroups = <BarChartGroupData>[];

    for (var i = 0; i < folds.length; i++) {
      final fold = folds[i];
      final barGroup = BarChartGroupData(
        x: i,
        barsSpace: 5,
        barRods: [
          _rod(fold.trainResults.excessSharpe, ChartColors.train),
          _rod(fold.valResults.excessSharpe, ChartColors.val),
          _rod(fold.testResults.excessSharpe, ChartColors.test)
        ]
      );
      barGroups.add(barGroup);
    }

    return Column(
      children: [
        const ChartLegend(
          labels: ["Train", "Validation", "Test"],
          colors: [ChartColors.train, ChartColors.val, ChartColors.test]
        ),
        const SizedBox(height: 5),
        Expanded(child: BarChart(BarChartData(
          minY: minY,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
          titlesData: titles(
            leftLabel: (value) => value.toStringAsFixed(2), 
            bottomLabel: (value) => "Fold ${value.toInt() + 1}"
          )
        )))
      ]
    );
  }
}

class OptimizerChart extends StatelessWidget {
  final FoldResults fold;

  const OptimizerChart({super.key, required this.fold});

  @override
  Widget build(BuildContext context) {
    final optResults = fold.optResults;
    
    double impToScore(Improvement imp) => imp.score;
    final trainScores = optResults.trainImprovements.map(impToScore).toList();
    final valScores = optResults.valImprovements.map(impToScore).toList();
    final scores = [...trainScores, ...valScores];

    final minY = scores.reduce(min);
    final maxY = scores.reduce(max);

    final data = LineChartData(
      minY: minY,
      maxY: maxY,
      borderData: FlBorderData(show: false),
      lineBarsData: [
        _line(fold.optResults.trainImprovements, ChartColors.train),
        _line(fold.optResults.valImprovements, ChartColors.val)
      ],
      titlesData: titles(
        leftLabel: (value) => value.toStringAsFixed(2),
        bottomLabel: (value) => value.toInt().toString()
      )
    );

    return Column(
      children: [
        const ChartLegend(
          labels: ["Train", "Validation"],
          colors: [ChartColors.train, ChartColors.val],
        ),
        const SizedBox(height: 8),
        Expanded(child: LineChart(data))
      ]
    );
  }

  LineChartBarData _line(List<Improvement> imps, Color color) {
    FlSpot impToSpot(Improvement imp) => FlSpot(imp.iter.toDouble(), imp.score);
    final spots = imps.map(impToSpot).toList();

    return LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 2,
      isCurved: false,
      dotData: const FlDotData(show: true)
    );
  }
}

class ExitReasonChart extends StatelessWidget {
  final FoldResults fold;

  const ExitReasonChart({super.key, required this.fold});

  @override
  Widget build(BuildContext context) {
    final counts = ResultsSplit.values.expand((split) {
      final results = fold.resultsFor(split);
      return [
        results.signalExits,
        results.stopLossExits,
        results.takeProfitExits,
        results.maxHoldExits
      ];
    });
    final maxCount = counts.reduce(max);
    final maxY = maxCount == 0 ? 50.0 : ((maxCount * 1.2) / 50).ceil() * 50.0;
    final barGroups = <BarChartGroupData>[];

    for (var i = 0; i < ResultsSplit.values.length; i++) {
      final split = ResultsSplit.values[i];
      final results = fold.resultsFor(split);
      final barGroup = BarChartGroupData(
        x: i,
        barsSpace: 5,
        barRods: [
          _rod(results.signalExits.toDouble(), ChartColors.signal),
          _rod(results.stopLossExits.toDouble(), ChartColors.stopLoss),
          _rod(results.takeProfitExits.toDouble(), ChartColors.takeProfit),
          _rod(results.maxHoldExits.toDouble(), ChartColors.maxHold)
        ]
      );
      barGroups.add(barGroup);
    }

    return Column(
      children: [
        const ChartLegend(
          labels: ["Signal", "Stop Loss", "Take Profit", "Max Hold Time"],
          colors: [ChartColors.signal, ChartColors.stopLoss, ChartColors.takeProfit, ChartColors.maxHold]
        ),
        const SizedBox(height: 5),
        Expanded(child: BarChart(BarChartData(
          minY: 0,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
          titlesData: titles(
            leftLabel: (value) => value.toInt().toString(),
            bottomLabel: (value) => switch (ResultsSplit.values[value.toInt()]) {
              ResultsSplit.train => "Train",
              ResultsSplit.val => "Validation",
              ResultsSplit.test => "Test"
            }
          )
        )))
      ]
    );
  }
}
