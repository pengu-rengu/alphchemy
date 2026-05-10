import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/results.dart";
import "package:alphchemy/widgets/padded_card.dart";
import "package:alphchemy/widgets/results/experiment_display.dart";
import "package:alphchemy/widgets/results/results_charts.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ResultsDashboard extends StatelessWidget {
  final String title;
  final List<FoldResults> folds;
  final Experiment? experiment;
  final int selectedFoldIdx;

  const ResultsDashboard({super.key, required this.title, required this.folds, required this.experiment, required this.selectedFoldIdx});

  @override
  Widget build(BuildContext context) {
    final fold = folds[selectedFoldIdx];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text("Experiment Results", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (experiment != null) ...[
            ExperimentDisplay(experiment: experiment!),
            const SizedBox(height: 16)
          ],
          ChartPanel(
            title: "Excess Sharpe",
            child: SharpeChart(folds: folds)
          ),
          const SizedBox(height: 16),
          FoldSelector(
            folds: folds,
            selectedFoldIndex: selectedFoldIdx
          ),
          const SizedBox(height: 16),
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
                      title: "Optimizer Improvements",
                      child: OptimizerChart(fold: fold)
                    )
                  ]
                )
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BacktestMetricsTable(fold: fold),
                    const SizedBox(height: 10),
                    ChartPanel(
                      title: "Exit Reasons",
                      child: ExitReasonChart(fold: fold)
                    )
                  ]
                )
              )
            ]
          )
        ]
      )
    );
  }
}

class FoldOptimizerTable extends StatelessWidget {
  final FoldResults fold;

  const FoldOptimizerTable({super.key, required this.fold});

  @override
  Widget build(BuildContext context) {
    final optResults = fold.optResults;

    return PaddedCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Fold and Optimizer"),
        const SizedBox(height: 5.0),
        ResultsTable(
          valueHeaders: const ["Value"],
          rows: [
            MetricTableRow(label: "Range", values: ["${fold.startIdx}-${fold.endIdx}"]),
            MetricTableRow(label: "Optimizer Iterations", values: [optResults.iters.toString()]),
            MetricTableRow(label: "Best Sequence", values: [optResults.bestSeq.join(" -> ")]),
            MetricTableRow(label: "Train Improvement Count", values: [optResults.trainImprovements.length.toString()]),
            MetricTableRow(label: "Validation Improvement Count", values: [optResults.valImprovements.length.toString()])
          ]
        )
      ]
    ));
  }
}

class BacktestMetricsTable extends StatelessWidget {
  final FoldResults fold;

  const BacktestMetricsTable({super.key, required this.fold});

  @override
  Widget build(BuildContext context) {
    return PaddedCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Backtest Metrics"),
        const SizedBox(height: 5.0),
        ResultsTable(
          valueHeaders: const ["Train", "Val", "Test"],
          rows: [
            _row("Validity", (results) => results.isInvalid ? "Invalid" : "Valid"),
            _row("Mean Hold Time", (results) => results.meanHoldTime.toStringAsFixed(2)),
            _row("Standard Dev. Hold Time", (results) => results.stdHoldTime.toStringAsFixed(2)),
            _row("Entries", (results) => results.entries.toString()),
            _row("Total Exits", (results) => results.totalExits.toString())
          ]
        )
      ]
    ));
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
  final List<String> valueHeaders;
  final List<MetricTableRow> rows;

  const ResultsTable({super.key, required this.valueHeaders, required this.rows});

  @override
  Widget build(BuildContext context) {
    final tableRows = <TableRow>[];
    final headerCells = _headerCells(context);
    final headerRow = TableRow(children: headerCells);
    tableRows.add(headerRow);

    for (final row in rows) {
      final rowCells = _rowCells(context, row);
      final tableRow = TableRow(children: rowCells);
      tableRows.add(tableRow);
    }

    return Table(
      border: const TableBorder(
        horizontalInside: BorderSide(color: Colors.white54),
        //verticalInside: BorderSide(color: Colors.white54)
      ),
      columnWidths: const <int, TableColumnWidth>{0: FlexColumnWidth(1.25)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: tableRows
    );
  }

  List<Widget> _headerCells(BuildContext context) {
    final cells = <Widget>[];
    final metricCell = _cell(context, "Metric", true);
    cells.add(metricCell);

    for (final header in valueHeaders) {
      final cell = _cell(context, header, true);
      cells.add(cell);
    }

    return cells;
  }

  List<Widget> _rowCells(BuildContext context, MetricTableRow row) {
    final cells = <Widget>[];
    final metricCell = _cell(context, row.label, false);
    cells.add(metricCell);

    for (final value in row.values) {
      final cell = _cell(context, value, false);
      cells.add(cell);
    }

    return cells;
  }

  Widget _cell(BuildContext context, String text, bool isHeader) {

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        //softWrap: true
      )
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
  final int selectedFoldIndex;

  const FoldSelector({
    super.key,
    required this.folds,
    required this.selectedFoldIndex
  });

  @override
  Widget build(BuildContext context) {
    final segments = <ButtonSegment<int>>[];

    for (var i = 0; i < folds.length; i++) {
      final label = "Fold ${i + 1}";
      final segment = ButtonSegment<int>(
        value: i,
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
          context.read<ResultsBloc>().add(SelectFold(foldIdx: foldIndex));
        }
      )
    );
  }
}
