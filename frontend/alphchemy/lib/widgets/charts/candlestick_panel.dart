import "dart:math";

import "package:alphchemy/model/feature_set/feature_set_values.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/widgets/chart_utils.dart";
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
        minX: 0,
        maxX: (ohlc.close.length - 1).toDouble(),
        minY: lowest,
        maxY: highest,
        candlestickTouchData: CandlestickTouchData(
          touchTooltipData: CandlestickTouchTooltipData(
            getTooltipItems: (painter, spot, spotIndex) {
              final color = painter.getMainColor(spot: spot, spotIndex: spotIndex);
              return CandlestickTooltipItem(
                "open: ${spot.open}\nhigh: ${spot.high}\nlow: ${spot.low}\nclose: ${spot.close}\n\n${formatDate(ohlc.timestamp[spot.x.toInt()])}",
                textStyle: Theme.of(context).textTheme.displayMedium!.copyWith(color: color),
              );
            }
          )
        ),
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
        titlesData: titles(
          leftLabel: (value) {
            final scaled = value.abs() >= 1000 ? value / 1000 : value;
            final suffix = value.abs() >= 1000 ? "k" : "";
            if (scaled == 0) return "0";
            final exp = (log(scaled.abs()) / ln10).floor();
            final decimals = max(0, 2 - exp);
            return "${scaled.toStringAsFixed(decimals)}$suffix";
          },
          bottomLabel: (value) => formatDate(ohlc.timestamp[value.floor()]),
          bottomInterval: (ohlc.timestamp.length / 5).ceilToDouble()
        )
      ))
    ));
  }
}