import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/model/results_data.dart";
import "package:alphchemy/widgets/results/results_charts.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ResultsDashboard extends StatelessWidget {
  final List<FoldResults> folds;
  final int selectedFoldIndex;

  const ResultsDashboard({
    super.key,
    required this.folds,
    required this.selectedFoldIndex
  });

  @override
  Widget build(BuildContext context) {
    if (folds.isEmpty) {
      return const Center(child: Text("No fold results"));
    }

    final fold = folds[selectedFoldIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Experiment Results", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          ChartPanel(
            title: "Excess Sharpe",
            child: SharpeChart(folds: folds)
          ),
          const SizedBox(height: 16),
          FoldSelector(
            folds: folds,
            selectedFoldIndex: selectedFoldIndex
          ),
          const SizedBox(height: 16),
          ResultsPanelGrid(
            children: [
              ResultsTablePanel(
                title: "Fold and Optimizer",
                child: FoldOptimizerTable(
                  folds: folds,
                  selectedFold: fold
                )
              ),
              ResultsTablePanel(
                title: "Backtest Metrics",
                child: BacktestMetricsTable(fold: fold)
              ),
              ChartPanel(
                title: "Optimizer Improvements",
                child: OptimizerChart(fold: fold)
              ),
              ChartPanel(
                title: "Exit Reasons",
                child: ExitReasonChart(fold: fold)
              )
            ]
          )
        ]
      )
    );
  }
}

class ResultsTablePanel extends StatelessWidget {
  final String title;
  final Widget child;

  const ResultsTablePanel({
    super.key,
    required this.title,
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    return ResultsPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child
        ]
      )
    );
  }
}

class FoldOptimizerTable extends StatelessWidget {
  final List<FoldResults> folds;
  final FoldResults selectedFold;

  const FoldOptimizerTable({
    super.key,
    required this.folds,
    required this.selectedFold
  });

  @override
  Widget build(BuildContext context) {
    final rows = <MetricTableRow>[];
    final foldCount = folds.length.toString();
    final rangeText = "${selectedFold.startIdx}-${selectedFold.endIdx}";
    final itersText = selectedFold.optResults.iters.toString();
    final bestSeqText = _bestSeqText();
    final trainCount = selectedFold.optResults.trainImprovements.length.toString();
    final valCount = selectedFold.optResults.valImprovements.length.toString();

    rows.add(MetricTableRow(label: "Folds", values: [foldCount]));
    rows.add(MetricTableRow(label: "Selected Range", values: [rangeText]));
    rows.add(MetricTableRow(label: "Optimizer Iters", values: [itersText]));
    rows.add(MetricTableRow(label: "Best Sequence", values: [bestSeqText]));
    rows.add(MetricTableRow(label: "Train Improvement Count", values: [trainCount]));
    rows.add(MetricTableRow(label: "Val Improvement Count", values: [valCount]));

    return ResultsValueTable(
      valueHeaders: const ["Value"],
      rows: rows
    );
  }

  String _bestSeqText() {
    if (selectedFold.optResults.bestSeq.isEmpty) {
      return "None";
    }

    return selectedFold.optResults.bestSeq.join(" -> ");
  }
}

class BacktestMetricsTable extends StatelessWidget {
  final FoldResults fold;

  const BacktestMetricsTable({
    super.key,
    required this.fold
  });

  @override
  Widget build(BuildContext context) {
    final rows = <MetricTableRow>[];

    rows.add(_row("Validity", _validityLabel));
    rows.add(_row("Mean Hold Time", _meanHoldTime));
    rows.add(_row("Std Hold Time", _stdHoldTime));
    rows.add(_row("Entries", _entries));
    rows.add(_row("Total Exits", _totalExits));

    return ResultsValueTable(
      valueHeaders: const ["Train", "Val", "Test"],
      rows: rows
    );
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

  String _validityLabel(BacktestResults results) {
    if (results.isInvalid) {
      return "Invalid";
    }

    return "Valid";
  }

  String _meanHoldTime(BacktestResults results) {
    return _decimal(results.meanHoldTime);
  }

  String _stdHoldTime(BacktestResults results) {
    return _decimal(results.stdHoldTime);
  }

  String _entries(BacktestResults results) {
    return results.entries.toString();
  }

  String _totalExits(BacktestResults results) {
    return results.totalExits.toString();
  }

  String _decimal(double value) {
    return value.toStringAsFixed(2);
  }
}

class ResultsValueTable extends StatelessWidget {
  final List<String> valueHeaders;
  final List<MetricTableRow> rows;

  const ResultsValueTable({
    super.key,
    required this.valueHeaders,
    required this.rows
  });

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

    const tableBorder = TableBorder(
      horizontalInside: BorderSide(color: Colors.white12)
    );

    return Table(
      border: tableBorder,
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(1.35)
      },
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
    final style = _textStyle(context, isHeader);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: style,
        softWrap: true
      )
    );
  }

  TextStyle? _textStyle(BuildContext context, bool isHeader) {
    final textTheme = Theme.of(context).textTheme;
    if (isHeader) {
      return textTheme.labelMedium;
    }

    return textTheme.bodyMedium;
  }
}

class MetricTableRow {
  final String label;
  final List<String> values;

  const MetricTableRow({
    required this.label,
    required this.values
  });
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

    for (var index = 0; index < folds.length; index += 1) {
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

class ResultsPanelGrid extends StatelessWidget {
  final List<Widget> children;

  const ResultsPanelGrid({
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
