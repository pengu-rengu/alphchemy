import "package:flutter/material.dart";

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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8)
      ),
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

class ResultsColors {
  static const train = Colors.lightBlueAccent;
  static const val = Colors.amberAccent;
  static const test = Colors.greenAccent;
  static const signal = Colors.cyanAccent;
  static const stopLoss = Colors.redAccent;
  static const takeProfit = Colors.tealAccent;
  static const maxHold = Colors.deepOrangeAccent;

  const ResultsColors();
}

class ResultsLegend extends StatelessWidget {
  final List<LegendItem> items;

  const ResultsLegend({
    super.key,
    required this.items
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final item in items)
          LegendPill(item: item)
      ]
    );
  }
}

class LegendItem {
  final String label;
  final Color color;

  const LegendItem({
    required this.label,
    required this.color
  });
}

class LegendPill extends StatelessWidget {
  final LegendItem item;

  const LegendPill({
    super.key,
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
