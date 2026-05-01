import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/model/results_data.dart";
import "package:alphchemy/widgets/results/results_chart_shell.dart";
import "package:alphchemy/widgets/results/results_charts.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ResultsDashboard extends StatelessWidget {
  final String title;
  final SuccessResults results;
  final int selectedFoldIndex;

  const ResultsDashboard({
    super.key,
    required this.title,
    required this.results,
    required this.selectedFoldIndex
  });

  @override
  Widget build(BuildContext context) {
    if (results.foldResults.isEmpty) {
      return const Center(child: Text("No fold results"));
    }

    final fold = results.foldResults[selectedFoldIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          ResultsSummary(results: results, selectedFold: fold),
          const SizedBox(height: 16),
          FoldSelector(
            results: results,
            selectedFoldIndex: selectedFoldIndex
          ),
          const SizedBox(height: 16),
          ChartPanel(
            title: "Excess Sharpe",
            child: SharpeChart(results: results)
          ),
          const SizedBox(height: 16),
          ResultsChartGrid(
            children: [
              ChartPanel(
                title: "Optimizer",
                child: OptimizerChart(fold: fold)
              ),
              ChartPanel(
                title: "Entries and Exits",
                child: EntriesExitsChart(results: results)
              ),
              ChartPanel(
                title: "Validity",
                child: ValidityChart(results: results)
              ),
              ChartPanel(
                title: "Exit Reasons",
                child: ExitReasonChart(fold: fold)
              ),
              ChartPanel(
                title: "Hold Time",
                child: HoldTimeChart(fold: fold)
              )
            ]
          )
        ]
      )
    );
  }
}

class ResultsSummary extends StatelessWidget {
  final SuccessResults results;
  final FoldResults selectedFold;

  const ResultsSummary({
    super.key,
    required this.results,
    required this.selectedFold
  });

  @override
  Widget build(BuildContext context) {
    final invalidText = _formatPercent(results.invalidFrac);
    final foldCount = results.foldResults.length.toString();
    final rangeText = "${selectedFold.startIdx}-${selectedFold.endIdx}";
    final sharpeText = results.overallExcessSharpe.toStringAsFixed(3);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        MetricTile(label: "Overall Excess Sharpe", value: sharpeText),
        MetricTile(label: "Invalid Folds", value: invalidText),
        MetricTile(label: "Folds", value: foldCount),
        MetricTile(label: "Selected Range", value: rangeText)
      ]
    );
  }

  String _formatPercent(double value) {
    final percent = value * 100.0;
    final rounded = percent.toStringAsFixed(0);
    return "$rounded%";
  }
}

class MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const MetricTile({
    super.key,
    required this.label,
    required this.value
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium)
        ]
      )
    );
  }
}

class FoldSelector extends StatelessWidget {
  final SuccessResults results;
  final int selectedFoldIndex;

  const FoldSelector({
    super.key,
    required this.results,
    required this.selectedFoldIndex
  });

  @override
  Widget build(BuildContext context) {
    final segments = <ButtonSegment<int>>[];

    for (var index = 0; index < results.foldResults.length; index += 1) {
      final label = "Fold ${index + 1}";
      final segment = ButtonSegment<int>(
        value: index,
        label: Text(label)
      );
      segments.add(segment);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<int>(
        showSelectedIcon: false,
        segments: segments,
        selected: <int>{selectedFoldIndex},
        onSelectionChanged: (selection) {
          final foldIndex = selection.first;
          context.read<ResultsBloc>().add(SelectFold(foldIndex: foldIndex));
        }
      )
    );
  }
}

class ResultsChartGrid extends StatelessWidget {
  final List<Widget> children;

  const ResultsChartGrid({
    super.key,
    required this.children
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900.0;
        const spacing = 16.0;
        final width = isNarrow
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing) / 2.0;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: width, child: child)
          ]
        );
      }
    );
  }
}
