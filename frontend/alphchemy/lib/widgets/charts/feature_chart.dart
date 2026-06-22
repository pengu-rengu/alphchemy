/*
import "dart:math";

import "package:alphchemy/main.dart";
import "package:alphchemy/model/experiment/features.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/widgets/chart_utils.dart";
import "package:alphchemy/widgets/charts/chart_colors.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:collection/collection.dart";

class FeatureChart extends StatelessWidget {
  final FeatureChartInfo info;
  final List<double>? values;
  final List<double> timestamps;

  const FeatureChart({super.key, required this.info, required this.values, required this.timestamps});

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
          child: values == null ? const CenterText("No values")
            : (info.isBarChart ? _BarSeriesChart(values: values!, color: color, timestamps: timestamps)
              : _LineSeriesChart(values: values!, color: color, refs: info.chartRefLines, timestamps: timestamps))
        )
      ]
    ));
  }
}

class _LineSeriesChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final Map<double, String> refs;
  final List<double> timestamps;

  const _LineSeriesChart({required this.values, required this.color, required this.refs, required this.timestamps});

  @override
  Widget build(BuildContext context) {
    final refColor = Theme.of(context).extension<AppColors>()!.fgColor2;

    return LineChart(LineChartData(
      minX: 0,
      maxX: (values.length - 1).toDouble(),
      minY: values.reduce(min),
      maxY: values.reduce(max),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(drawVerticalLine: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((spot) {
            final date = formatDate(timestamps[spot.x.toInt()]);
            return LineTooltipItem("${spot.y}\n$date", TextStyle(color: color));
          }).toList()
        )
      ),
      extraLinesData: ExtraLinesData(horizontalLines: refs.entries.map((entry) => HorizontalLine(
        y: entry.key,
        color: refColor,
        strokeWidth: 1.0,
        dashArray: const [5, 5],
        label: HorizontalLineLabel(
          show: true,
          labelResolver: (_) => entry.value,
          style: TextStyle(color: refColor, fontSize: 10),
          alignment: Alignment.topRight
        )
      )).toList()),
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
          color: color,
          barWidth: 2,
          isCurved: false,
          dotData: const FlDotData(show: false)
        )
      ],
      titlesData: titles(
        leftLabel: _formatTick,
        bottomLabel: (value) {
          final idx = value.round();
          if (idx < 0 || idx >= timestamps.length) return "";
          return formatDate(timestamps[idx]);
        },
        bottomInterval: (timestamps.length / 5.0).ceilToDouble()
      )
    ));
  }
}

class _BarSeriesChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final List<double> timestamps;

  const _BarSeriesChart({required this.values, required this.color, required this.timestamps});

  @override
  Widget build(BuildContext context) {
    final absValues = values.map((value) => value.abs());
    final bound = absValues.reduce(max);
    final stride = (timestamps.length / 5).ceil();

    return BarChart(BarChartData(
      minY: -bound,
      maxY: bound,
      barGroups: values.mapIndexed((idx, value) => BarChartGroupData(
        x: idx,
        barRods: [BarChartRodData(
          toY: value,
          color: value >= 0 ? CandlestickColor.up.color : CandlestickColor.down.color,
          width: 2,
          borderRadius: BorderRadius.zero
        )]
      )).toList(),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(drawVerticalLine: false),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final date = formatDate(timestamps[group.x]);
            return BarTooltipItem("${rod.toY}\n$date", TextStyle(color: rod.color));
          }
        )
      ),
      titlesData: titles(
        leftLabel: _formatTick,
        bottomLabel: (value) {
          final idx = value.floor();
          if (idx % stride != 0) {
            return "";
          }
          return formatDate(timestamps[idx]);
        }
      )
    ));
  }
}

String _formatTick(double value) {
  final absValue = value.abs();
  if (absValue >= 100) {
    return value.toStringAsFixed(0);
  }
  if (absValue >= 1) {
    return value.toStringAsFixed(2);
  }
  return value.toStringAsFixed(4);
}
*/
