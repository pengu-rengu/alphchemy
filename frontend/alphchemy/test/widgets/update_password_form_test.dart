import "package:alphchemy/blocs/auth/auth_bloc.dart";
import "package:alphchemy/widgets/update_password_form.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:forui/forui.dart";
import "package:supabase_flutter/supabase_flutter.dart" show AuthClientOptions, SupabaseClient;

void main() {
  testWidgets("change password card stays compact on reset page", (tester) async {
    final client = _testClient();
    final authBloc = AuthBloc(client: client);
    const card = Center(child: SizedBox(
      width: 360.0,
      child: ChangePasswordCard(title: "Reset password", stretchButton: true)
    ));
    final app = _testApp(authBloc: authBloc, child: card);

    await tester.pumpWidget(app);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ChangePasswordCard)).height, lessThan(400.0));
    expect(tester.getSize(find.widgetWithText(FButton, "Update password")).width, greaterThan(300.0));
    expect(find.text("New password"), findsOneWidget);
    expect(find.text("Confirm password"), findsOneWidget);
    expect(find.text("Update password"), findsOneWidget);
  });

  testWidgets("change password card stays compact in settings scroll view", (tester) async {
    final client = _testClient();
    final authBloc = AuthBloc(client: client);
    const card = SingleChildScrollView(child: Column(children: [ChangePasswordCard()]));
    final app = _testApp(authBloc: authBloc, child: card);

    await tester.pumpWidget(app);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ChangePasswordCard)).height, lessThan(400.0));
    expect(tester.getSize(find.widgetWithText(FButton, "Update password")).width, lessThan(250.0));
    expect(find.text("New password"), findsOneWidget);
    expect(find.text("Confirm password"), findsOneWidget);
    expect(find.text("Update password"), findsOneWidget);
  });
}

SupabaseClient _testClient() {
  const authOptions = AuthClientOptions(autoRefreshToken: false);
  return SupabaseClient("https://example.supabase.co", "test-key", authOptions: authOptions);
}

Widget _testApp({required AuthBloc authBloc, required Widget child}) {
  final theme = FThemes.neutral.light.desktop;
  final materialTheme = theme.toApproximateMaterialTheme();
  final themedChild = FTheme(data: theme, child: child);
  final provider = BlocProvider<AuthBloc>.value(value: authBloc, child: themedChild);
  return MaterialApp(theme: materialTheme, home: Scaffold(body: provider));
}
