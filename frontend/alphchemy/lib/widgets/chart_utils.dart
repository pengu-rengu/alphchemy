import "package:fl_chart/fl_chart.dart";
import "package:alphchemy/widgets/misc_widgets.dart";

AxisTitles shownTitle({required double size, required String Function(double) label, double? interval}) {
  return AxisTitles(sideTitles: SideTitles(
    showTitles: true,
    reservedSize: size,
    interval: interval,
    getTitlesWidget: (value, meta) => SideTitleWidget(
      meta: meta,
      child: NormalText(label(value)),
    )
  ));
}

FlTitlesData titles({required String Function(double) leftLabel, required String Function(double) bottomLabel, double? bottomInterval}) {
  const noTitle = AxisTitles(sideTitles: SideTitles());

  return FlTitlesData(
    topTitles: noTitle,
    rightTitles: noTitle,
    leftTitles: shownTitle(size: 50.0, label: leftLabel),
    bottomTitles: shownTitle(size: 50.0, label: bottomLabel, interval: bottomInterval)
  );
}