import "dart:math";

import "package:alphchemy/main.dart";
import "package:alphchemy/widgets/charts/chart_colors.dart";
import "package:alphchemy/widgets/widget_utils.dart";
import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";

class FeaturePanel extends StatelessWidget {
  final String featureId;
  final String featureName;
  final String output;
  final List<double> values;

  const FeaturePanel({
    super.key,
    required this.featureId,
    required this.featureName,
    required this.output,
    required this.values
  });

  @override
  Widget build(BuildContext context) {
    final color = featureColors[featureName] ?? light1;
    final isBars = featureName == "raw_returns" || (featureName == "normalized_macd" && output == "hist");
    final refs = _referencesFor(featureName);

    return PaddedCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 8, height: 8, color: color),
          const SizedBox(width: 6),
          BoldText(featureId),
          const SizedBox(width: 10),
          NormalText(featureName)
        ]),
        const SizedBox(height: 5),
        SizedBox(
          height: 130,
          child: values.isEmpty
            ? const Center(child: NormalText("No values"))
            : (isBars ? _BarSeriesChart(values: values, color: color) : _LineSeriesChart(values: values, color: color, refs: refs))
        )
      ]
    ));
  }

  List<_RefLine> _referencesFor(String name) {
    if (name == "rsi") {
      return const [_RefLine(value: 70, label: "70"), _RefLine(value: 30, label: "30")];
    }
    if (name == "stochastic") {
      return const [_RefLine(value: 80, label: "80"), _RefLine(value: 20, label: "20")];
    }
    const normalized = {"normalized_sma", "normalized_ema", "roc", "normalized_bb", "normalized_dc", "normalized_atr"};
    if (normalized.contains(name)) {
      return const [_RefLine(value: 1.0, label: "1.00")];
    }
    return const [];
  }
}

class _RefLine {
  final double value;
  final String label;

  const _RefLine({required this.value, required this.label});
}

class _LineSeriesChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final List<_RefLine> refs;

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

    final extraLines = refs.map((ref) => HorizontalLine(
      y: ref.value,
      color: light2,
      strokeWidth: 1.0,
      dashArray: const [4, 4],
      label: HorizontalLineLabel(
        show: true,
        labelResolver: (_) => ref.label,
        style: const TextStyle(color: light2, fontSize: 10),
        alignment: Alignment.topRight
      )
    )).toList();

    return LineChart(LineChartData(
      minY: minValue,
      maxY: maxValue,
      borderData: FlBorderData(border: const Border.fromBorderSide(BorderSide(color: dark3))),
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
