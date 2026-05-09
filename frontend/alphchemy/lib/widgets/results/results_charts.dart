import "package:alphchemy/model/results_data.dart";
import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";

class ResultsPanelCard extends StatelessWidget {
  final Widget child;

  const ResultsPanelCard({
    super.key,
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    final shape = RoundedRectangleBorder(borderRadius: borderRadius);
    const padding = EdgeInsets.all(12);
    final paddedChild = Padding(
      padding: padding,
      child: child
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: shape,
      child: paddedChild
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
    return ResultsPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(height: 240, child: child)
        ]
      )
    );
  }
}

class SharpeChart extends StatelessWidget {
  final List<FoldResults> folds;

  const SharpeChart({
    super.key,
    required this.folds
  });

  @override
  Widget build(BuildContext context) {
    final data = BarChartData(
      minY: _minY(),
      maxY: _maxY(),
      barGroups: _groups(),
      borderData: FlBorderData(show: true),
      gridData: const FlGridData(show: true),
      titlesData: _ChartTitles.foldTitles(folds.length)
    );

    return Column(
      children: [
        const _ChartLegend(
          items: [
            _LegendItem(label: "Train", color: _ChartColors.train),
            _LegendItem(label: "Val", color: _ChartColors.val),
            _LegendItem(label: "Test", color: _ChartColors.test)
          ]
        ),
        const SizedBox(height: 8),
        Expanded(child: BarChart(data))
      ]
    );
  }

  List<BarChartGroupData> _groups() {
    final groups = <BarChartGroupData>[];

    for (var index = 0; index < folds.length; index += 1) {
      final fold = folds[index];
      final rods = <BarChartRodData>[];
      final trainRod = _rod(fold.trainResults.excessSharpe, _ChartColors.train);
      final valRod = _rod(fold.valResults.excessSharpe, _ChartColors.val);
      final testRod = _rod(fold.testResults.excessSharpe, _ChartColors.test);
      rods.add(trainRod);
      rods.add(valRod);
      rods.add(testRod);

      final group = BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: rods
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

  double _maxY() {
    final values = _values();
    return _ChartBounds.maxY(values);
  }

  double _minY() {
    final values = _values();
    return _ChartBounds.minY(values);
  }

  List<double> _values() {
    final values = <double>[];

    for (final fold in folds) {
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
    final data = LineChartData(
      minY: _minY(),
      maxY: _maxY(),
      lineBarsData: _lines(),
      borderData: FlBorderData(show: true),
      gridData: const FlGridData(show: true),
      titlesData: const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))
      )
    );

    return Column(
      children: [
        const _ChartLegend(
          items: [
            _LegendItem(label: "Train", color: _ChartColors.train),
            _LegendItem(label: "Val", color: _ChartColors.val)
          ]
        ),
        const SizedBox(height: 8),
        Expanded(child: LineChart(data))
      ]
    );
  }

  List<LineChartBarData> _lines() {
    final lines = <LineChartBarData>[];
    final trainLine = _line(fold.optResults.trainImprovements, _ChartColors.train);
    final valLine = _line(fold.optResults.valImprovements, _ChartColors.val);
    lines.add(trainLine);
    lines.add(valLine);

    return lines;
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
    return _ChartBounds.maxY(values);
  }

  double _minY() {
    final values = _scores();
    return _ChartBounds.minY(values);
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

class ExitReasonChart extends StatelessWidget {
  final FoldResults fold;

  const ExitReasonChart({
    super.key,
    required this.fold
  });

  @override
  Widget build(BuildContext context) {
    final data = BarChartData(
      minY: 0,
      maxY: _maxY(),
      barGroups: _groups(),
      borderData: FlBorderData(show: true),
      gridData: const FlGridData(show: true),
      titlesData: _ChartTitles.splitTitles()
    );

    return Column(
      children: [
        const _ChartLegend(
          items: [
            _LegendItem(label: "Signal", color: _ChartColors.signal),
            _LegendItem(label: "Stop", color: _ChartColors.stopLoss),
            _LegendItem(label: "Profit", color: _ChartColors.takeProfit),
            _LegendItem(label: "Max Hold", color: _ChartColors.maxHold)
          ]
        ),
        const SizedBox(height: 8),
        Expanded(child: BarChart(data))
      ]
    );
  }

  List<BarChartGroupData> _groups() {
    final groups = <BarChartGroupData>[];
    const splits = ResultsSplit.values;

    for (var index = 0; index < splits.length; index += 1) {
      final split = splits[index];
      final results = fold.resultsFor(split);
      final rods = <BarChartRodData>[];
      final signalRod = _rod(results.signalExits.toDouble(), _ChartColors.signal);
      final stopLossRod = _rod(results.stopLossExits.toDouble(), _ChartColors.stopLoss);
      final takeProfitRod = _rod(results.takeProfitExits.toDouble(), _ChartColors.takeProfit);
      final maxHoldRod = _rod(results.maxHoldExits.toDouble(), _ChartColors.maxHold);
      rods.add(signalRod);
      rods.add(stopLossRod);
      rods.add(takeProfitRod);
      rods.add(maxHoldRod);

      final group = BarChartGroupData(
        x: index,
        barsSpace: 3,
        barRods: rods
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

  double _maxY() {
    final values = _values();
    return _ChartBounds.maxY(values);
  }

  List<double> _values() {
    final values = <double>[];

    for (final split in ResultsSplit.values) {
      final results = fold.resultsFor(split);
      values.add(results.signalExits.toDouble());
      values.add(results.stopLossExits.toDouble());
      values.add(results.takeProfitExits.toDouble());
      values.add(results.maxHoldExits.toDouble());
    }

    return values;
  }
}

class _ChartBounds {
  const _ChartBounds();

  static double maxY(List<double> values) {
    var maxValue = 1.0;

    for (final value in values) {
      if (value > maxValue) {
        maxValue = value;
      }
    }

    return maxValue * 1.2;
  }

  static double minY(List<double> values) {
    var minValue = 0.0;

    for (final value in values) {
      if (value < minValue) {
        minValue = value;
      }
    }

    return minValue * 1.2;
  }
}

class _ChartColors {
  static const train = Colors.lightBlueAccent;
  static const val = Colors.amberAccent;
  static const test = Colors.greenAccent;
  static const signal = Colors.cyanAccent;
  static const stopLoss = Colors.redAccent;
  static const takeProfit = Colors.tealAccent;
  static const maxHold = Colors.deepOrangeAccent;

  const _ChartColors();
}

class _ChartTitles {
  const _ChartTitles();

  static FlTitlesData foldTitles(int foldCount) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) {
            return _foldTitle(value, meta, foldCount);
          }
        )
      )
    );
  }

  static FlTitlesData splitTitles() {
    return const FlTitlesData(
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: _splitTitle
        )
      )
    );
  }

  static Widget _foldTitle(double value, TitleMeta meta, int foldCount) {
    final index = value.toInt();
    if (index < 0) {
      return const SizedBox.shrink();
    }
    if (index >= foldCount) {
      return const SizedBox.shrink();
    }

    return SideTitleWidget(
      meta: meta,
      child: Text("F${index + 1}")
    );
  }

  static Widget _splitTitle(double value, TitleMeta meta) {
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

  static String _splitLabel(ResultsSplit split) {
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

class _ChartLegend extends StatelessWidget {
  final List<_LegendItem> items;

  const _ChartLegend({
    required this.items
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final item in items)
          _LegendPill(item: item)
      ]
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;

  const _LegendItem({
    required this.label,
    required this.color
  });
}

class _LegendPill extends StatelessWidget {
  final _LegendItem item;

  const _LegendPill({
    required this.item
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          color: item.color
        ),
        const SizedBox(width: 6),
        Text(item.label)
      ]
    );
  }
}
