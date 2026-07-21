import "package:alphchemy_app/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:forui/forui.dart";

void main() {
  testWidgets("header truncates a long flexible title without overflowing", (tester) async {
    await tester.binding.setSurfaceSize(const Size(600.0, 200.0));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const title = "dot_rsi28_ema100_roc36_orgate_delay2_pen001_strongboth_sl03_nthresh5_val015_test035_bal100_qty5_logic_5fold_2yr_jul18_s9016";
    await tester.pumpWidget(_headerApp(title));

    expect(tester.takeException(), isNull);
    expect(find.text("Action"), findsOneWidget);

    final titleText = tester.widget<Text>(find.text(title));
    expect(titleText.maxLines, 1);
    expect(titleText.overflow, TextOverflow.ellipsis);
  });

  testWidgets("json view updates when json changes", (tester) async {
    const emptyNet = '{"nodes":[]}';
    const fourNodeNet = '{"nodes":[1,2,3,4]}';
    final emptyApp = _jsonViewApp(emptyNet);

    await tester.pumpWidget(emptyApp);

    final emptyCount = find.text("[0]");
    expect(emptyCount, findsOneWidget);

    final fourNodeApp = _jsonViewApp(fourNodeNet);
    await tester.pumpWidget(fourNodeApp);
    await tester.pump();

    final fourNodeCount = find.text("[4]");
    expect(fourNodeCount, findsOneWidget);
    expect(emptyCount, findsNothing);
  });
}

Widget _headerApp(String title) {
  final theme = FThemes.neutral.light.desktop;
  final materialTheme = theme.toApproximateMaterialTheme();
  final header = Header(
    left: [
      const SizedBox(width: 40.0),
      const SizedBox(width: 10.0),
      Flexible(child: LargeText(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis
      )),
      const SizedBox(width: 10.0)
    ],
    right: const [SizedBox(width: 200.0, child: NormalText("Action"))]
  );
  final themedHeader = FTheme(data: theme, child: header);
  return MaterialApp(theme: materialTheme, home: Scaffold(body: themedHeader));
}

Widget _jsonViewApp(String json) {
  final theme = FThemes.neutral.light.desktop;
  final materialTheme = theme.toApproximateMaterialTheme();
  final jsonView = JsonView(json: json, height: 400);
  final themedView = FTheme(data: theme, child: jsonView);
  return MaterialApp(theme: materialTheme, home: themedView);
}
