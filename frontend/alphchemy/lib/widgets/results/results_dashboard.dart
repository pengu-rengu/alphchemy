import "package:alphchemy/blocs/experiments/results_bloc.dart";
import "package:alphchemy/model/results.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/widgets/editor/experiment_editor.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/results/results_charts.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";
import "package:json_editor_flutter/json_editor_flutter.dart";

class ResultsDashboard extends StatelessWidget {
  final String title;
  final List<FoldResults> folds;
  final String source;
  final String experiment;
  final int foldIdx;

  const ResultsDashboard({super.key, required this.title, required this.folds, required this.source, required this.experiment, required this.foldIdx});

  @override
  Widget build(BuildContext context) {
    final fold = folds[foldIdx];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10.0),
          PaddedCard(child: FAccordion(children: [
            FAccordionItem(
              title: const LargeText("Experiment Source"),
              child: ExperimentEditor.readOnly(source: source)
            )
          ])),
          const SizedBox(height: 10),
          PaddedCard(child: FAccordion(children: [
            FAccordionItem(
              title: const LargeText("Experiment Configuration"),
              child: SizedBox(
                height: 500,
                child: Material(
                  type: MaterialType.transparency,
                  child: JsonEditor(
                    json: experiment,
                    onChanged: (_) {},
                    themeColor: context.theme.colors.border,
                    enableMoreOptions: false,
                    enableKeyEdit: false,
                    enableValueEdit: false
                  )
                )
              )
            )
          ])),
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
        child: PaddedCard(child: FAccordion(
          control: FAccordionControl.managed(
            onChange: (indices) => setExpanded(indices.isNotEmpty)
          ),
          children: const [
            FAccordionItem(
              title: LargeText("Metric Charts"),
              child: SizedBox.shrink()
            )
          ]
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
    final startDatetime = formatIsoDate(fold.trainStartTimestamp);
    final endDatetime = formatIsoDate(fold.testEndTimestamp);
    final range = "$startDatetime → $endDatetime";

    return PaddedCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LargeText("Fold and Optimizer"),
        const SizedBox(height: 5.0),
        ResultsTable(
          headers: const ["Value"],
          rows: [
            MetricTableRow(label: "Range", values: [range]),
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
    return FAccordion(children: [
      FAccordionItem(
        title: NormalText(title),
        child: JsonView(json: network, height: 400)
      )
    ]);
  }
}

class BacktestMetricsTable extends StatelessWidget {
  final FoldResults fold;

  const BacktestMetricsTable({super.key, required this.fold});

  @override
  Widget build(BuildContext context) {
    final trainStartDatetime = formatIsoDate(fold.trainStartTimestamp);
    final trainEndDatetime = formatIsoDate(fold.trainEndTimestamp);
    final valStartDatetime = formatIsoDate(fold.valStartTimestamp);
    final valEndDatetime = formatIsoDate(fold.valEndTimestamp);
    final testStartDatetime = formatIsoDate(fold.testStartTimestamp);
    final testEndDatetime = formatIsoDate(fold.testEndTimestamp);
    final trainRange = "$trainStartDatetime → $trainEndDatetime";
    final valRange = "$valStartDatetime → $valEndDatetime";
    final testRange = "$testStartDatetime → $testEndDatetime";

    final rows = <MetricTableRow>[
      MetricTableRow(label: "Range", values: [trainRange, valRange, testRange]),
      _row("Validity", (results) => results.isInvalid ? "Invalid" : "Valid")
    ];

    bool hasMetric(BacktestMetric metric) => fold.trainResults.metrics.containsKey(metric);
    final metrics = BacktestMetric.values.where(hasMetric);
    for (final metric in metrics) {
      String formatMetric(results) => _formatValue(results.metrics[metric]!);
      final row = _row(metric.displayName, formatMetric);
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
    return value.toString();
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
        horizontalInside: BorderSide(color: context.theme.colors.border)
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
        child: Row(children: [
          for (var i = 0; i < folds.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: _FoldButton(foldIdx: i, selected: selectedFoldIdx == i)
            )
        ])
      )
    );
  }
}

class _FoldButton extends StatelessWidget {
  final int foldIdx;
  final bool selected;

  const _FoldButton({required this.foldIdx, required this.selected});

  @override
  Widget build(BuildContext context) {
    final label = "Fold ${foldIdx + 1}";
    final variant = selected ? FButtonVariant.primary : FButtonVariant.outline;
    return FButton(
      variant: variant,
      onPress: () => context.read<ResultsBloc>().add(SelectFold(foldIdx: foldIdx)),
      child: selected ? InvertedText(label) : NormalText(label)
    );
  }
}
