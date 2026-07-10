import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:forui/forui.dart";

void main() {
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

Widget _jsonViewApp(String json) {
  final theme = FThemes.neutral.light.desktop;
  final materialTheme = theme.toApproximateMaterialTheme();
  final jsonView = JsonView(json: json, height: 400);
  final themedView = FTheme(data: theme, child: jsonView);
  return MaterialApp(theme: materialTheme, home: themedView);
}
