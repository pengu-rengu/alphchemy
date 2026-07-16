import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:uuid/uuid.dart";

sealed class ApiKeyEvent {
  const ApiKeyEvent();
}

class LoadApiKey extends ApiKeyEvent {
  const LoadApiKey();
}

class GenerateApiKey extends ApiKeyEvent {
  const GenerateApiKey();
}

sealed class ApiKeyState {
  const ApiKeyState();
}

class ApiKeyInitial extends ApiKeyState {
  const ApiKeyInitial();
}

class ApiKeyLoading extends ApiKeyState {
  const ApiKeyLoading();
}

class ApiKeyLoaded extends ApiKeyState {
  final String? apiKey;

  const ApiKeyLoaded({required this.apiKey});
}

class ApiKeyError extends ApiKeyState {
  final String message;

  const ApiKeyError({required this.message});
}

class ApiKeyBloc extends Bloc<ApiKeyEvent, ApiKeyState> {
  final SupabaseClient client;

  ApiKeyBloc({required this.client}) : super(const ApiKeyInitial()) {
    on<LoadApiKey>(_onLoad);
    on<GenerateApiKey>(_onGenerate);
  }

  Future<void> _onLoad(LoadApiKey event, Emitter<ApiKeyState> emit) async {
    const loading = ApiKeyLoading();
    emit(loading);

    try {
      final table = client.from("api_keys");
      final selected = table.select("api_key");
      final owned = selected.eq("user_id", _currentUserId());
      final rows = await owned.limit(1);
      final apiKey = rows.isEmpty ? null : rows.first["api_key"] as String;
      final loaded = ApiKeyLoaded(apiKey: apiKey);
      emit(loaded);
    } catch (error) {
      final message = error.toString();
      final errorState = ApiKeyError(message: message);
      emit(errorState);
    }
  }

  Future<void> _onGenerate(GenerateApiKey event, Emitter<ApiKeyState> emit) async {
    const loading = ApiKeyLoading();
    emit(loading);

    try {
      const uuid = Uuid();
      final apiKey = uuid.v4();
      final userId = _currentUserId();
      final table = client.from("api_keys");
      await table.upsert({
        "user_id": userId,
        "api_key": apiKey
      }, onConflict: "user_id");
      final loaded = ApiKeyLoaded(apiKey: apiKey);
      emit(loaded);
    } catch (error) {
      final message = error.toString();
      final errorState = ApiKeyError(message: message);
      emit(errorState);
    }
  }

  String _currentUserId() {
    final user = client.auth.currentUser;
    if (user == null) throw StateError("API key access requires authentication");

    return user.id;
  }
}
