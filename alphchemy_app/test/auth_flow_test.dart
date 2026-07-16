import "package:alphchemy_app/blocs/auth/auth_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:supabase_flutter/supabase_flutter.dart" show AuthClientOptions, AuthFlowType, SupabaseClient;

void main() {
  test("reset password requires an email", () async {
    final client = SupabaseClient("https://example.supabase.co", "test-key");
    final bloc = AuthBloc(client: client);
    final states = expectLater(bloc.stream, emitsInOrder([
      isA<AuthSubmitting>(),
      predicate<AuthState>((state) => state is AuthFailed && state.message == "Email is required")
    ]));

    bloc.add(const ResetPasswordSubmitted(email: ""));

    await states;
    await bloc.close();
    client.dispose();
  });

  test("reset password sends the reset password redirect", () async {
    late Uri requestUri;
    final httpClient = MockClient((request) async {
      requestUri = request.url;
      return http.Response("{}", 200);
    });
    const authOptions = AuthClientOptions(authFlowType: AuthFlowType.implicit);
    final client = SupabaseClient("https://example.supabase.co", "test-key", authOptions: authOptions, httpClient: httpClient);
    final bloc = AuthBloc(client: client);
    final states = expectLater(bloc.stream, emitsInOrder([
      isA<AuthSubmitting>(),
      predicate<AuthState>((state) => state is AuthInfo && state.message == "Check your email for a password reset link")
    ]));

    bloc.add(const ResetPasswordSubmitted(email: "user@example.com"));

    await states;
    final redirectValue = requestUri.queryParameters["redirect_to"]!;
    final redirectUri = Uri.parse(redirectValue);
    expect(redirectUri.path, "/reset-password");
    await bloc.close();
    client.dispose();
  });

  test("change password requires matching passwords", () async {
    final client = SupabaseClient("https://example.supabase.co", "test-key");
    final bloc = AuthBloc(client: client);
    final states = expectLater(bloc.stream, emitsInOrder([
      isA<AuthSubmitting>(),
      predicate<AuthState>((state) => state is AuthFailed && state.message == "Passwords do not match")
    ]));

    bloc.add(const ChangePasswordSubmitted(password: "password-one", confirmPassword: "password-two"));

    await states;
    await bloc.close();
    client.dispose();
  });
}
