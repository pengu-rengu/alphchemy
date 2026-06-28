import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

sealed class ValidationEvent {
  const ValidationEvent();
}

class ValidateExperiment extends ValidationEvent {
  final String source;

  const ValidateExperiment({required this.source});
}

class UpdateValidationJob extends ValidationEvent {
  final int id;

  const UpdateValidationJob({required this.id});
}

class ShowValidationError extends ValidationEvent {
  final String message;

  const ShowValidationError({required this.message});
}

class ResetValidation extends ValidationEvent {
  const ResetValidation();
}

sealed class ValidationState {
  const ValidationState();
}

class ValidationInitial extends ValidationState {
  const ValidationInitial();
}

class ValidationWorking extends ValidationState {
  const ValidationWorking();
}

class ValidationCompleted extends ValidationState {
  final String message;
  final bool isValid;

  const ValidationCompleted({required this.message, required this.isValid});
}

class ValidationError extends ValidationState {
  final String message;

  const ValidationError({required this.message});
}

class ValidationBloc extends Bloc<ValidationEvent, ValidationState> {
  final SupabaseClient client;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;

  ValidationBloc({required this.client}) : super(const ValidationInitial()) {
    on<ValidateExperiment>(_onValidate);
    on<UpdateValidationJob>(_onUpdate);
    on<ShowValidationError>(_onError);
    on<ResetValidation>(_onReset);
  }

  Future<void> _onValidate(ValidateExperiment event, Emitter<ValidationState> emit) async {
    emit(const ValidationWorking());

    try {
      final table = client.from("validation_jobs");
      final insert = table.insert({
        "source": event.source,
        "status": "working"
      });
      final jobId = (await insert.select("id").single())["id"] as int;

      await _streamSubscription?.cancel();
      final stream = table.stream(primaryKey: ["id"]);
      final filtered = stream.eq("id", jobId);
      final single = filtered.limit(1);

      _streamSubscription = single.listen(
        (rows) {
          final event = UpdateValidationJob(id: jobId);
          add(event);
        },
        onError: (Object error) {
          final event = ShowValidationError(message: error.toString());
          add(event);
        }
      );

      // Safety net: query once now in case the worker finished before the
      // realtime subscription was ready (the UPDATE event would be missed).
      final initialCheck = UpdateValidationJob(id: jobId);
      add(initialCheck);
    } catch (error) {
      final newState = ValidationError(message: error.toString());
      emit(newState);
    }
  }

  Future<void> _onUpdate(UpdateValidationJob event, Emitter<ValidationState> emit) async {
    try {
      final query = client.from("validation_jobs").select();
      final filtered = query.eq("id", event.id);
      final rows = await filtered.limit(1);

      if (rows.isEmpty) {
        _emitError(emit: emit, error: "Unable to find validation job");
        return;
      }

      final row = rows.first;
      final status = row["status"] as String;

      if (status == "working") {
        emit(const ValidationWorking());
        return;
      }

      await _streamSubscription?.cancel();
      _streamSubscription = null;

      if (status == "completed_valid") {
        final newState = ValidationCompleted(message: row["result_message"] as String, isValid: true);
        emit(newState);
      } else if (status == "completed_invalid") {
        final newState = ValidationCompleted(message: row["result_message"] as String, isValid: false);
        emit(newState);
      } else if (status == "errored") {
        _emitError(emit: emit, error: row["result_message"]);
      } else {
        _emitError(emit: emit, error: "Unknown validation job status: $status");
      }
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onError(ShowValidationError event, Emitter<ValidationState> emit) {
    _emitError(emit: emit, error: event.message);
  }

  void _onReset(ResetValidation event, Emitter<ValidationState> emit) {
    emit(const ValidationInitial());
  }

  void _emitError({required Emitter<ValidationState> emit, required dynamic error}) {
    final newState = ValidationError(message: error.toString());
    emit(newState);
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}
