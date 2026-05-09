import "dart:io";

import "package:alphchemy/pages/results_page.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../helpers/supabase_test_server.dart";

void main() {
  testWidgets("uses a back button instead of the navigation rail", (WidgetTester tester) async {
    final response = SupabaseTestResponse(body: {
      "results": {
        "error": "Loaded",
        "is_internal": false
      }
    });
    final server = await SupabaseTestServer.start([response]);
    final client = server.createClient();
    addTearDown(client.dispose);
    addTearDown(server.close);

    await _withRealHttp(() async {
      await _pumpHost(tester, client);
      await _openResults(tester);
    });

    final request = server.requests.first;
    expect(request.method, "GET");
    expect(request.query["id"], "eq.42");
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await _tapBack(tester);

    expect(find.text("Experiments"), findsOneWidget);
  });
}

Future<void> _withRealHttp(Future<void> Function() action) async {
  final overrides = _RealHttpOverrides();
  await HttpOverrides.runZoned(
    action,
    createHttpClient: overrides.createHttpClient
  );
}

Future<void> _pumpHost(
  WidgetTester tester,
  SupabaseClient client
) async {
  final app = RepositoryProvider<SupabaseClient>.value(
    value: client,
    child: const MaterialApp(
      home: _ResultsHost()
    )
  );
  await tester.pumpWidget(app);
}

Future<void> _openResults(WidgetTester tester) async {
  final openButton = find.text("Open Results");
  await tester.tap(openButton);
  await tester.pumpAndSettle();
}

Future<void> _tapBack(WidgetTester tester) async {
  final backButton = find.byIcon(Icons.arrow_back);
  await tester.tap(backButton);
  await tester.pumpAndSettle();
}

class _ResultsHost extends StatelessWidget {
  const _ResultsHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            final route = MaterialPageRoute<void>(
              builder: (routeContext) {
                return const ResultsPage(
                  experimentId: 42,
                  title: "Completed Experiment"
                );
              }
            );
            final navigator = Navigator.of(context);
            navigator.push(route);
          },
          child: const Text("Open Results")
        )
      ),
      appBar: AppBar(
        title: const Text("Experiments")
      )
    );
  }
}

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}
