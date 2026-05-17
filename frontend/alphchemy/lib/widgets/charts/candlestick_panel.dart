import "dart:math";

import "package:alphchemy/model/feature_set/feature_set_values.dart";
import "package:alphchemy/widgets/charts/chart_colors.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";

class CandlestickPanel extends StatelessWidget {
  final OhlcSeries ohlc;

  const CandlestickPanel({super.key, required this.ohlc});

  @override
  Widget build(BuildContext context) {
    final spots = <CandlestickSpot>[];
    var highest = ohlc.high[0];
    var lowest = ohlc.low[0];

    for (var i = 0; i < ohlc.close.length; i++) {
      spots.add(CandlestickSpot(
        x: i.toDouble(),
        open: ohlc.open[i],
        high: ohlc.high[i],
        low: ohlc.low[i],
        close: ohlc.close[i]
      ));

      highest = max(ohlc.high[i], highest);
      lowest = min(ohlc.low[i], lowest);
    }

    return PaddedCard(child: SizedBox(
      height: 400,
      child: CandlestickChart(CandlestickChartData(
        candlestickSpots: spots,
        minY: lowest,
        maxY: highest,
        candlestickPainter: DefaultCandlestickPainter(
          candlestickStyleProvider: (CandlestickSpot spot, int index) {
            final color = spot.isUp ? CandlestickColor.up.color : CandlestickColor.down.color;
            return CandlestickStyle(
              lineColor: color,
              lineWidth: 1.0,
              bodyStrokeColor: color,
              bodyStrokeWidth: 0.0,
              bodyFillColor: color,
              bodyWidth: 5.0,
              bodyRadius: 0.0
            );
          }
        ),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: _titles(minY: lowest, maxY: highest, n: ohlc.close.length)
      ))
    ));
  }

  FlTitlesData _titles({required double minY, required double maxY, required int n}) {
    const noTitle = AxisTitles(sideTitles: SideTitles());
    String leftLabel(double value) => value.toStringAsFixed(2);
    String bottomLabel(double value) {
      final idx = value.toInt();
      if (idx < 0 || idx >= n) return "";
      return idx.toString();
    }

    return FlTitlesData(
      topTitles: noTitle,
      rightTitles: noTitle,
      leftTitles: AxisTitles(sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 50,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: NormalText(leftLabel(value))
        )
      )),
      bottomTitles: AxisTitles(sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 25,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: NormalText(bottomLabel(value))
        )
      ))
    );
  }
}
