import "package:alphchemy_app/blocs/auth/api_key_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:supabase_flutter/supabase_flutter.dart";

void main() {
  test("loading an API key requires authentication", () async {
    final client = SupabaseClient("https://example.supabase.co", "test-key");
    final bloc = ApiKeyBloc(client: client);
    final states = expectLater(bloc.stream, emitsInOrder([
      isA<ApiKeyLoading>(),
      predicate<ApiKeyState>((state) {
        return state is ApiKeyError && state.message.contains("API key access requires authentication");
      })
    ]));

    bloc.add(const LoadApiKey());

    await states;
    await bloc.close();
    client.dispose();
  });
}
