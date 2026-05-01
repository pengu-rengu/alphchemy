import "package:alphchemy/model/results_data.dart";
import "package:alphchemy/widgets/results/results_chart_shell.dart";
import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";

class SharpeChart extends StatelessWidget {
  final SuccessResults results;

  const SharpeChart({
    super.key,
    required this.results
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ResultsLegend(
          items: [
            LegendItem(label: "Train", color: ResultsColors.train),
            LegendItem(label: "Val", color: ResultsColors.val),
            LegendItem(label: "Test", color: ResultsColors.test)
          ]
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              minY: _minY(),
              maxY: _maxY(),
              barGroups: _groups(),
              borderData: FlBorderData(show: true),
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: _bottomTitle
                  )
                )
              )
            )
          )
        )
      ]
    );
  }

  List<BarChartGroupData> _groups() {
    final groups = <BarChartGroupData>[];

    for (var index = 0; index < results.foldResults.length; index += 1) {
      final fold = results.foldResults[index];
      final group = BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          _rod(fold.trainResults.excessSharpe, ResultsColors.train),
          _rod(fold.valResults.excessSharpe, ResultsColors.val),
          _rod(fold.testResults.excessSharpe, ResultsColors.test)
        ]
      );
      groups.add(group);
    }

    return groups;
  }

  BarChartRodData _rod(double value, Color color) {
    return BarChartRodData(
      toY: value,
      color: color,
      width: 9,
      borderRadius: BorderRadius.circular(2)
    );
  }

  Widget _bottomTitle(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0) {
      return const SizedBox.shrink();
    }
    if (index >= results.foldResults.length) {
      return const SizedBox.shrink();
    }

    return SideTitleWidget(
      meta: meta,
      child: Text("F${index + 1}")
    );
  }

  double _maxY() {
    final values = _values();
    var maxValue = 1.0;

    for (final value in values) {
      if (value > maxValue) {
        maxValue = value;
      }
    }

    return maxValue * 1.2;
  }

  double _minY() {
    final values = _values();
    var minValue = 0.0;

    for (final value in values) {
      if (value < minValue) {
        minValue = value;
      }
    }

    return minValue * 1.2;
  }

  List<double> _values() {
    final values = <double>[];

    for (final fold in results.foldResults) {
      values.add(fold.trainResults.excessSharpe);
      values.add(fold.valResults.excessSharpe);
      values.add(fold.testResults.excessSharpe);
    }

    return values;
  }
}

class OptimizerChart extends StatelessWidget {
  final FoldResults fold;

  const OptimizerChart({
    super.key,
    required this.fold
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ResultsLegend(
          items: [
            LegendItem(label: "Train", color: ResultsColors.train),
            LegendItem(label: "Val", color: ResultsColors.val)
          ]
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: _minY(),
              maxY: _maxY(),
              lineBarsData: [
                _line(fold.optResults.trainImprovements, ResultsColors.train),
                _line(fold.optResults.valImprovements, ResultsColors.val)
              ],
              borderData: FlBorderData(show: true),
              gridData: const FlGridData(show: true),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))
              )
            )
          )
        )
      ]
    );
  }

  LineChartBarData _line(List<Improvement> improvements, Color color) {
    final spots = <FlSpot>[];

    for (final improvement in improvements) {
      final iter = improvement.iter.toDouble();
      final score = improvement.score;
      final spot = FlSpot(iter, score);
      spots.add(spot);
    }

    return LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 2,
      isCurved: false,
      dotData: const FlDotData(show: true)
    );
  }

  double _maxY() {
    final values = _scores();
    var maxValue = 1.0;

    for (final value in values) {
      if (value > maxValue) {
        maxValue = value;
      }
    }

    return maxValue * 1.2;
  }

  double _minY() {
    final values = _scores();
    var minValue = 0.0;

    for (final value in values) {
      if (value < minValue) {
        minValue = value;
      }
    }

    return minValue * 1.2;
  }

  List<double> _scores() {
    final scores = <double>[];

    for (final improvement in fold.optResults.trainImprovements) {
      scores.add(improvement.score);
    }
    for (final improvement in fold.optResults.valImprovements) {
      scores.add(improvement.score);
    }

    return scores;
  }
}

class EntriesExitsChart extends StatelessWidget {
  final SuccessResults results;

  const EntriesExitsChart({
    super.key,
    required this.results
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ResultsLegend(
          items: [
            LegendItem(label: "Entries", color: ResultsColors.train),
            LegendItem(label: "Total Exits", color: ResultsColors.val)
          ]
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: _maxY(),
              barGroups: _groups(),
              borderData: FlBorderData(show: true),
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: _bottomTitle
                  )
                )
              )
            )
          )
        )
      ]
    );
  }

  List<BarChartGroupData> _groups() {
    final groups = <BarChartGroupData>[];

    for (var index = 0; index < results.foldResults.length; index += 1) {
      final testResults = results.foldResults[index].testResults;
      final group = BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          _rod(testResults.entries.toDouble(), ResultsColors.train),
          _rod(testResults.totalExits.toDouble(), ResultsColors.val)
        ]
      );
      groups.add(group);
    }

    return groups;
  }

  BarChartRodData _rod(double value, Color color) {
    return BarChartRodData(
      toY: value,
      color: color,
      width: 12,
      borderRadius: BorderRadius.circular(2)
    );
  }

  Widget _bottomTitle(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0) {
      return const SizedBox.shrink();
    }
    if (index >= results.foldResults.length) {
      return const SizedBox.shrink();
    }

    return SideTitleWidget(
      meta: meta,
      child: Text("F${index + 1}")
    );
  }

  double _maxY() {
    var maxValue = 1.0;

    for (final fold in results.foldResults) {
      final entries = fold.testResults.entries.toDouble();
      final exits = fold.testResults.totalExits.toDouble();

      if (entries > maxValue) {
        maxValue = entries;
      }
      if (exits > maxValue) {
        maxValue = exits;
      }
    }

    return maxValue * 1.2;
  }
}

class ValidityChart extends StatelessWidget {
  final SuccessResults results;

  const ValidityChart({
    super.key,
    required this.results
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ResultsLegend(
          items: [
            LegendItem(label: "Train", color: ResultsColors.train),
            LegendItem(label: "Val", color: ResultsColors.val),
            LegendItem(label: "Test", color: ResultsColors.test)
          ]
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: 1.2,
              barGroups: _groups(),
              borderData: FlBorderData(show: true),
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: _bottomTitle
                  )
                )
              )
            )
          )
        )
      ]
    );
  }

  List<BarChartGroupData> _groups() {
    final groups = <BarChartGroupData>[];

    for (var index = 0; index < results.foldResults.length; index += 1) {
      final fold = results.foldResults[index];
      final group = BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          _rod(fold.trainResults.isInvalid, ResultsColors.train),
          _rod(fold.valResults.isInvalid, ResultsColors.val),
          _rod(fold.testResults.isInvalid, ResultsColors.test)
        ]
      );
      groups.add(group);
    }

    return groups;
  }

  BarChartRodData _rod(bool isInvalid, Color color) {
    final value = isInvalid ? 1.0 : 0.0;

    return BarChartRodData(
      toY: value,
      color: color,
      width: 9,
      borderRadius: BorderRadius.circular(2)
    );
  }

  Widget _bottomTitle(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0) {
      return const SizedBox.shrink();
    }
    if (index >= results.foldResults.length) {
      return const SizedBox.shrink();
    }

    return SideTitleWidget(
      meta: meta,
      child: Text("F${index + 1}")
    );
  }
}

class ExitReasonChart extends StatelessWidget {
  final FoldResults fold;

  const ExitReasonChart({
    super.key,
    required this.fold
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ResultsLegend(
          items: [
            LegendItem(label: "Signal", color: ResultsColors.signal),
            LegendItem(label: "Stop", color: ResultsColors.stopLoss),
            LegendItem(label: "Profit", color: ResultsColors.takeProfit),
            LegendItem(label: "Max Hold", color: ResultsColors.maxHold)
          ]
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: _maxY(),
              barGroups: _groups(),
              borderData: FlBorderData(show: true),
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: _bottomTitle
                  )
                )
              )
            )
          )
        )
      ]
    );
  }

  List<BarChartGroupData> _groups() {
    final groups = <BarChartGroupData>[];
    const splits = ResultsSplit.values;

    for (var index = 0; index < splits.length; index += 1) {
      final split = splits[index];
      final results = fold.resultsFor(split);
      final group = BarChartGroupData(
        x: index,
        barsSpace: 3,
        barRods: [
          _rod(results.signalExits.toDouble(), ResultsColors.signal),
          _rod(results.stopLossExits.toDouble(), ResultsColors.stopLoss),
          _rod(results.takeProfitExits.toDouble(), ResultsColors.takeProfit),
          _rod(results.maxHoldExits.toDouble(), ResultsColors.maxHold)
        ]
      );
      groups.add(group);
    }

    return groups;
  }

  BarChartRodData _rod(double value, Color color) {
    return BarChartRodData(
      toY: value,
      color: color,
      width: 7,
      borderRadius: BorderRadius.circular(2)
    );
  }

  Widget _bottomTitle(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0) {
      return const SizedBox.shrink();
    }
    if (index >= ResultsSplit.values.length) {
      return const SizedBox.shrink();
    }

    final split = ResultsSplit.values[index];
    final label = _splitLabel(split);

    return SideTitleWidget(
      meta: meta,
      child: Text(label)
    );
  }

  double _maxY() {
    var maxValue = 1.0;

    for (final split in ResultsSplit.values) {
      final results = fold.resultsFor(split);
      final values = [
        results.signalExits,
        results.stopLossExits,
        results.takeProfitExits,
        results.maxHoldExits
      ];

      for (final value in values) {
        final doubleValue = value.toDouble();
        if (doubleValue > maxValue) {
          maxValue = doubleValue;
        }
      }
    }

    return maxValue * 1.2;
  }

  String _splitLabel(ResultsSplit split) {
    switch (split) {
      case ResultsSplit.train:
        return "Train";
      case ResultsSplit.val:
        return "Val";
      case ResultsSplit.test:
        return "Test";
    }
  }
}

class HoldTimeChart extends StatelessWidget {
  final FoldResults fold;

  const HoldTimeChart({
    super.key,
    required this.fold
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ResultsLegend(
          items: [
            LegendItem(label: "Mean", color: ResultsColors.train),
            LegendItem(label: "Std", color: ResultsColors.val)
          ]
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: _maxY(),
              barGroups: _groups(),
              borderData: FlBorderData(show: true),
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: _bottomTitle
                  )
                )
              )
            )
          )
        )
      ]
    );
  }

  List<BarChartGroupData> _groups() {
    final groups = <BarChartGroupData>[];
    const splits = ResultsSplit.values;

    for (var index = 0; index < splits.length; index += 1) {
      final split = splits[index];
      final results = fold.resultsFor(split);
      final group = BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          _rod(results.meanHoldTime, ResultsColors.train),
          _rod(results.stdHoldTime, ResultsColors.val)
        ]
      );
      groups.add(group);
    }

    return groups;
  }

  BarChartRodData _rod(double value, Color color) {
    return BarChartRodData(
      toY: value,
      color: color,
      width: 12,
      borderRadius: BorderRadius.circular(2)
    );
  }

  Widget _bottomTitle(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0) {
      return const SizedBox.shrink();
    }
    if (index >= ResultsSplit.values.length) {
      return const SizedBox.shrink();
    }

    final split = ResultsSplit.values[index];
    final label = _splitLabel(split);

    return SideTitleWidget(
      meta: meta,
      child: Text(label)
    );
  }

  double _maxY() {
    var maxValue = 1.0;

    for (final split in ResultsSplit.values) {
      final results = fold.resultsFor(split);

      if (results.meanHoldTime > maxValue) {
        maxValue = results.meanHoldTime;
      }
      if (results.stdHoldTime > maxValue) {
        maxValue = results.stdHoldTime;
      }
    }

    return maxValue * 1.2;
  }

  String _splitLabel(ResultsSplit split) {
    switch (split) {
      case ResultsSplit.train:
        return "Train";
      case ResultsSplit.val:
        return "Val";
      case ResultsSplit.test:
        return "Test";
    }
  }
}
