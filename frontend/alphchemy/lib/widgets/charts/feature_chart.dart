import "dart:math";

import "package:alphchemy/main.dart";
import "package:alphchemy/model/experiment/features.dart";
import "package:alphchemy/widgets/charts/chart_colors.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";

class FeatureChart extends StatelessWidget {
  final FeatureChartInfo info;
  final List<double>? values;

  const FeatureChart({super.key, required this.info, required this.values});

  @override
  Widget build(BuildContext context) {
    final color = featureColors[info.featureName]!;

    return PaddedCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 10, height: 10, color: color),
          const SizedBox(width: 5),
          BoldText(info.id),
          const SizedBox(width: 5),
          NormalText(info.featureName)
        ]),
        const SizedBox(height: 5),
        SizedBox(
          height: 150,
          child: values == null
            ? const Center(child: NormalText("No values"))
            : (info.isBarChart
              ? _BarSeriesChart(values: values!, color: color)
              : _LineSeriesChart(values: values!, color: color, refs: info.chartRefLines))
        )
      ]
    ));
  }
}

class _LineSeriesChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final Map<double, String> refs;

  const _LineSeriesChart({required this.values, required this.color, required this.refs});

  @override
  Widget build(BuildContext context) {
    final meaningful = <double>[];
    for (final value in values) {
      if (value.isFinite && value != 0.0) meaningful.add(value);
    }
    if (meaningful.isEmpty) meaningful.add(0.0);

    var minValue = meaningful.reduce(min);
    var maxValue = meaningful.reduce(max);
    final span = max(maxValue - minValue, 1e-9);
    minValue -= span * 0.08;
    maxValue += span * 0.08;

    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (!value.isFinite) continue;
      if (value == 0.0 && i < values.length / 3) continue;
      spots.add(FlSpot(i.toDouble(), value));
    }

    final extraLines = refs.entries.map((entry) => HorizontalLine(
      y: entry.key,
      color: light2,
      strokeWidth: 1.0,
      dashArray: const [4, 4],
      label: HorizontalLineLabel(
        show: true,
        labelResolver: (_) => entry.value,
        style: const TextStyle(color: light2, fontSize: 10),
        alignment: Alignment.topRight
      )
    )).toList();

    return LineChart(LineChartData(
      minY: minValue,
      maxY: maxValue,
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(drawVerticalLine: false),
      extraLinesData: ExtraLinesData(horizontalLines: extraLines),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: color,
          barWidth: 1.4,
          isCurved: false,
          dotData: const FlDotData(show: false)
        )
      ],
      titlesData: _featureTitles(label: (value) => _formatTick(value))
    ));
  }
}

class _BarSeriesChart extends StatelessWidget {
  final List<double> values;
  final Color color;

  const _BarSeriesChart({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    final meaningful = <double>[];
    for (final value in values) {
      if (value.isFinite) meaningful.add(value);
    }

    var bound = 0.0;
    for (final value in meaningful) {
      final absValue = value.abs();
      if (absValue > bound) bound = absValue;
    }
    if (bound == 0.0) bound = 1.0;

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (!value.isFinite) continue;
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: value,
          color: value >= 0 ? CandlestickColor.up.color : CandlestickColor.down.color,
          width: 2,
          borderRadius: BorderRadius.zero
        )
      ]));
    }

    return BarChart(BarChartData(
      minY: -bound,
      maxY: bound,
      barGroups: groups,
      borderData: FlBorderData(border: const Border.fromBorderSide(BorderSide(color: dark3))),
      gridData: const FlGridData(drawVerticalLine: false),
      titlesData: _featureTitles(label: (value) => _formatTick(value))
    ));
  }
}

FlTitlesData _featureTitles({required String Function(double) label}) {
  const noTitle = AxisTitles(sideTitles: SideTitles());
  return FlTitlesData(
    topTitles: noTitle,
    rightTitles: noTitle,
    bottomTitles: noTitle,
    leftTitles: AxisTitles(sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 56,
      getTitlesWidget: (value, meta) => SideTitleWidget(
        meta: meta,
        child: NormalText(label(value))
      )
    ))
  );
}

String _formatTick(double value) {
  final absValue = value.abs();
  if (absValue >= 100) return value.toStringAsFixed(0);
  if (absValue >= 1) return value.toStringAsFixed(2);
  return value.toStringAsFixed(4);
}
