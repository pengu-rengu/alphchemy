import "package:alphchemy/main.dart";
import "package:alphchemy/model/feature_set/feature_set_values.dart";
import "package:alphchemy/widgets/charts/chart_colors.dart";
import "package:alphchemy/widgets/widget_utils.dart";
import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";

class CandlestickPanel extends StatelessWidget {
  final OhlcSeries ohlc;

  const CandlestickPanel({super.key, required this.ohlc});

  @override
  Widget build(BuildContext context) {
    if (ohlc.close.isEmpty) {
      return const PaddedCard(child: Center(child: NormalText("No OHLC data")));
    }

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

      if (ohlc.high[i] > highest) highest = ohlc.high[i];
      if (ohlc.low[i] < lowest) lowest = ohlc.low[i];
    }

    final span = highest - lowest;
    final padded = span <= 0 ? 1.0 : span * 0.04;
    final minY = lowest - padded;
    final maxY = highest + padded;

    final chart = CandlestickChart(
      CandlestickChartData(
        candlestickSpots: spots,
        minY: minY,
        maxY: maxY,
        candlestickPainter: DefaultCandlestickPainter(
          candlestickStyleProvider: _styleFor
        ),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(
          border: const Border.fromBorderSide(BorderSide(color: dark3))
        ),
        titlesData: _titles(minY: minY, maxY: maxY, n: ohlc.close.length)
      )
    );

    return PaddedCard(
      child: SizedBox(height: 360, child: chart)
    );
  }

  CandlestickStyle _styleFor(CandlestickSpot spot, int index) {
    final color = spot.isUp ? CandlestickColor.up.color : CandlestickColor.down.color;
    final fill = spot.isUp ? dark2 : color;
    return CandlestickStyle(
      lineColor: color,
      lineWidth: 1.0,
      bodyStrokeColor: color,
      bodyStrokeWidth: 1.0,
      bodyFillColor: fill,
      bodyWidth: 4.0,
      bodyRadius: 0.0
    );
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
        reservedSize: 56,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: NormalText(leftLabel(value))
        )
      )),
      bottomTitles: AxisTitles(sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 22,
        interval: (n / 6).clamp(1, double.infinity),
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: NormalText(bottomLabel(value))
        )
      ))
    );
  }
}
