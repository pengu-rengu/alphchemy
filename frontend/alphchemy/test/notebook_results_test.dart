import "package:alphchemy/main.dart";
import "package:alphchemy/model/notebook/query.dart";
import "package:alphchemy/pages/notebook_page.dart";
import "package:alphchemy/widgets/notebook/box_plot.dart";
import "package:alphchemy/widgets/notebook/notebook_tile.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

Widget testApp(Widget child) {
  return MaterialApp(
    theme: lightTheme,
    home: Scaffold(body: child)
  );
}

void main() {
  testWidgets("box plot shows no results for null result", (tester) async {
    await tester.pumpWidget(testApp(const BoxPlot(result: null)));

    expect(find.text("— no results —"), findsOneWidget);
    expect(find.text("— pending —"), findsNothing);
  });

  testWidgets("empty persisted results do not throw", (tester) async {
    final query = Query(
      id: "query-1",
      select: ["results.mean.test_results.excess_sharpe"],
      filters: [],
      results: []
    );

    await tester.pumpWidget(testApp(ResultsSection(query: query)));

    expect(tester.takeException(), isNull);
    expect(find.text("— no results —"), findsNothing);
    expect(find.text("— pending —"), findsNothing);
  });

  testWidgets("available results show five number summary", (tester) async {
    final result = QueryResults(
      min: 1.0,
      q1: 2.0,
      median: 3.0,
      q3: 4.0,
      max: 5.0
    );
    final query = Query(
      id: "query-1",
      select: ["results.mean.test_results.excess_sharpe"],
      filters: [],
      results: [result]
    );

    await tester.pumpWidget(testApp(ResultsSection(query: query)));

    expect(find.text("1.00 · 2.00 · 3.00 · 4.00 · 5.00"), findsOneWidget);
  });

  testWidgets("notebook error banner displays message", (tester) async {
    await tester.pumpWidget(testApp(const NotebookErrorBanner(message: "bad query")));

    expect(find.text("bad query"), findsOneWidget);
  });
}
