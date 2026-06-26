import "package:alphchemy/blocs/experiments/results_bloc.dart";
//import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/results.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/results/results_charts.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ResultsDashboard extends StatelessWidget {
  final String title;
  final List<FoldResults> folds;
  //final Experiment experiment;
  final String experiment;
  final int foldIdx;

  const ResultsDashboard({super.key, required this.title, required this.folds, required this.experiment, required this.foldIdx});

  @override
  Widget build(BuildContext context) {
    final fold = folds[foldIdx];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10.0),
          PaddedCard(child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            title: const LargeText("Experiment Configuration"),
            children: [
              NormalText(experiment)
            ]
          )),
          const SizedBox(height: 10),
          MetricChartsSection(folds: folds),
          const SizedBox(height: 10),
          FoldSelector(
            folds: folds,
            selectedFoldIdx: foldIdx
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FoldOptimizerTable(fold: fold),
                    const SizedBox(height: 10),
                    ChartPanel(
                      title: "Equity Curve",
                      child: EquityCurveChart(fold: fold)
                    ),
                    const SizedBox(height: 10),
                    ChartPanel(
                      title: "Optimizer Improvements",
                      child: OptimizerChart(fold: fold)
                    )
                  ]
                )
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BacktestMetricsTable(fold: fold)
              )
            ]
          ),
          const SizedBox(height: 50.0)
        ]
      )
    );
  }
}

class MetricChartsSection extends StatefulWidget {
  final List<FoldResults> folds;

  const MetricChartsSection({super.key, required this.folds});

  @override
  State<MetricChartsSection> createState() => _MetricChartsSectionState();
}

class _MetricChartsSectionState extends State<MetricChartsSection> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      SizedBox(
        width: double.infinity,
        child: PaddedCard(child: ExpansionTile(
          initiallyExpanded: expanded,
          tilePadding: EdgeInsets.zero,
          title: const LargeText("Metric Charts"),
          onExpansionChanged: setExpanded,
          children: const []
        ))
      )
    ];

    if (expanded) {
      children.addAll(metricCharts());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
    );
  }

  void setExpanded(bool value) {
    setState(() {
      expanded = value;
    });
  }

  List<Widget> metricCharts() {
    final widgets = <Widget>[];

    for (final metric in BacktestMetric.values) {
      if (!widget.folds.first.trainResults.metrics.containsKey(metric)) {
        continue;
      }

      widgets.add(ChartPanel(
        title: metric.displayName,
        child: MetricChart(folds: widget.folds, metric: metric)
      ));
      widgets.add(const SizedBox(height: 10));
    }

    return widgets;
  }
}

class FoldOptimizerTable extends StatelessWidget {
  final FoldResults fold;

  const FoldOptimizerTable({super.key, required this.fold});

  @override
  Widget build(BuildContext context) {
    final optResults = fold.optResults;
    final startDatetime = fold.startTimestamp;

    return PaddedCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LargeText("Fold and Optimizer"),
        const SizedBox(height: 5.0),
        ResultsTable(
          headers: const ["Value"],
          rows: [
            MetricTableRow(label: "Range", values: ["$startDatetime → ${fold.endTimestamp}"]),
            MetricTableRow(label: "Optimizer Iterations", values: [optResults.iters.toString()]),
            MetricTableRow(label: "Best Train Sequence", values: [optResults.bestTrainSeq.join(" -> ")]),
            MetricTableRow(label: "Best Val Sequence", values: [optResults.bestValSeq.join(" -> ")]),
            MetricTableRow(label: "Train Improvement Count", values: [optResults.trainImps.length.toString()]),
            MetricTableRow(label: "Validation Improvement Count", values: [optResults.valImps.length.toString()])
          ]
        ),
        const SizedBox(height: 5.0),
        BestNetworkSection(
          title: "Best Train Network",
          network: optResults.bestTrainNet
        ),
        BestNetworkSection(
          title: "Best Val Network",
          network: optResults.bestValNet
        )
      ]
    ));
  }
}

class BestNetworkSection extends StatelessWidget {
  final String title;
  final String network;

  const BestNetworkSection({super.key, required this.title, required this.network});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: NormalText(title),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: NormalText(network)
          )
        )
      ]
    );
  }
}

class BacktestMetricsTable extends StatelessWidget {
  final FoldResults fold;

  const BacktestMetricsTable({super.key, required this.fold});

  @override
  Widget build(BuildContext context) {
    final trainRange = "${fold.trainStartTimestamp} → ${fold.trainEndTimestamp}";
    final valRange = "${fold.valStartTimestamp} → ${fold.valEndTimestamp}";
    final testRange = "${fold.testStartTimestamp} → ${fold.testEndTimestamp}";

    final rows = <MetricTableRow>[
      MetricTableRow(label: "Range", values: [trainRange, valRange, testRange]),
      _row("Validity", (results) => results.isInvalid ? "Invalid" : "Valid")
    ];

    bool hasMetric(BacktestMetric metric) => fold.trainResults.metrics.containsKey(metric);
    final metrics = BacktestMetric.values.where(hasMetric);
    for (final metric in metrics) {
      String formatValue(results) => _formatValue(results.metrics[metric]!);
      final row = _row(metric.displayName, formatValue);
      rows.add(row);
    }

    return PaddedCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LargeText("Backtest Metrics"),
        const SizedBox(height: 5.0),
        ResultsTable(
          headers: const ["Train", "Val", "Test"],
          rows: rows
        )
      ]
    ));
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      final asInt = value.toInt();
      return asInt.toString();
    }
    return value.toStringAsFixed(2);
  }

  MetricTableRow _row(String label, String Function(BacktestResults results) format) {
    final values = <String>[];
    final trainValue = format(fold.trainResults);
    final valValue = format(fold.valResults);
    final testValue = format(fold.testResults);

    values.add(trainValue);
    values.add(valValue);
    values.add(testValue);

    return MetricTableRow(label: label, values: values);
  }
}

class ResultsTable extends StatelessWidget {
  final List<String> headers;
  final List<MetricTableRow> rows;

  const ResultsTable({super.key, required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    final tableRows = <TableRow>[];
    final headerCells = _headerCells();
    final headerRow = TableRow(children: headerCells);
    tableRows.add(headerRow);

    for (final row in rows) {
      final rowCells = _rowCells(row);
      final tableRow = TableRow(children: rowCells);
      tableRows.add(tableRow);
    }

    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: Theme.of(context).dividerTheme.color!),
      ),
      columnWidths: const <int, TableColumnWidth>{0: FlexColumnWidth(1.25)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: tableRows
    );
  }

  List<Widget> _headerCells() {
    final cells = <Widget>[];
    final metricCell = _cell("Metric");
    cells.add(metricCell);

    for (final header in headers) {
      final cell = _cell(header);
      cells.add(cell);
    }

    return cells;
  }

  List<Widget> _rowCells(MetricTableRow row) {
    final cells = <Widget>[];
    final metricCell = _cell(row.label);
    cells.add(metricCell);

    for (final value in row.values) {
      final cell = _cell(value);
      cells.add(cell);
    }

    return cells;
  }

  Widget _cell(String text) {

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: NormalText(text)
    );
  }

}

class MetricTableRow {
  final String label;
  final List<String> values;

  const MetricTableRow({required this.label, required this.values});
}

class FoldSelector extends StatelessWidget {
  final List<FoldResults> folds;
  final int selectedFoldIdx;

  const FoldSelector({super.key, required this.folds, required this.selectedFoldIdx});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: (() {
            final segments = <ButtonSegment<int>>[];

            for (var i = 0; i < folds.length; i++) {
              final label = "Fold ${i + 1}";
              final segment = ButtonSegment<int>(
                value: i,
                label: selectedFoldIdx == i ? InvertedText(label) : NormalText(label)
              );
              segments.add(segment);
            }

            return segments;
          })(),
          selected: <int>{selectedFoldIdx},
          onSelectionChanged: (selection) {
            final foldIndex = selection.first;
            context.read<ResultsBloc>().add(SelectFold(foldIdx: foldIndex));
          }
        )
      )
    );
  }
}
