import "package:alphchemy_app/model/notebook/query.dart";
import "package:alphchemy_app/widgets/notebook/notebook_tile.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:forui/forui.dart";

void main() {
  testWidgets("result rows render ids only for window selections", (tester) async {
    final aggregateResult = QueryResults(
      path: "mean(experiment.score)",
      values: [2.0],
      ids: [],
      skipped: 0
    );
    final windowResult = QueryResults(
      path: "1(experiment.score)",
      values: [3.0],
      ids: [7],
      skipped: 0
    );
    final theme = FThemes.neutral.light.desktop;
    final aggregateRow = ResultsRow(result: aggregateResult);
    final windowRow = ResultsRow(result: windowResult);
    final rows = Column(children: [aggregateRow, windowRow]);
    final scaffold = Scaffold(body: rows);
    final themed = FTheme(data: theme, child: scaffold);
    final app = MaterialApp(home: themed);

    await tester.pumpWidget(app);

    expect(find.text("2.0"), findsOneWidget);
    expect(find.text("3.0 (7)"), findsOneWidget);
  });
}
