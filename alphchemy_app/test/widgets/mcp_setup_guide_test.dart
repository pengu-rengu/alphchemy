import "package:alphchemy_app/pages/settings_page.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:forui/forui.dart";

void main() {
  testWidgets("MCP guide includes authenticated Codex and Claude Code URLs", (tester) async {
    const apiKey = "test-api-key";
    const guide = McpSetupGuide(apiKey: apiKey);
    final theme = FThemes.neutral.light.desktop;
    final materialTheme = theme.toApproximateMaterialTheme();
    final themedGuide = FTheme(data: theme, child: guide);
    final app = MaterialApp(
      theme: materialTheme,
      home: Scaffold(body: themedGuide)
    );

    await tester.pumpWidget(app);

    const mcpUrl = "http://localhost:8000/mcp/test-api-key";
    expect(find.text("codex mcp add alphchemy --url $mcpUrl"), findsOneWidget);
    expect(find.text("claude mcp add --transport http alphchemy $mcpUrl"), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsNWidgets(2));
  });
}
