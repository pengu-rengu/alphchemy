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

const timeoutDuration = Duration(seconds: 30);

class ValidationBloc extends Bloc<ValidationEvent, ValidationState> {
  final SupabaseClient client;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  Timer? _timeoutTimer;

  ValidationBloc({required this.client}) : super(const ValidationInitial()) {
    on<ValidateExperiment>(_onValidate);
    on<UpdateValidationJob>(_onUpdate);
    on<ShowValidationError>(_onError);
    on<ResetValidation>(_onReset);
  }

  Future<void> _onValidate(ValidateExperiment event, Emitter<ValidationState> emit) async {
    emit(const ValidationWorking());
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(timeoutDuration, () {
      const event = ShowValidationError(message: "Validation timed out after 30 seconds");
      add(event);
    });

    try {
      final table = client.from("validation_jobs");
      final insert = table.insert({
        "source": event.source,
        "status": "working"
      });
      final jobId = (await insert.select("id").single())["id"] as int;

      if (!(_timeoutTimer?.isActive ?? false)) return;

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

      if (!(_timeoutTimer?.isActive ?? false)) {
        await _cancelJob();
        return;
      }

      // Safety net: query once now in case the worker finished before the
      // realtime subscription was ready (the UPDATE event would be missed).
      final initialCheck = UpdateValidationJob(id: jobId);
      add(initialCheck);
    } catch (error) {
      if (!(_timeoutTimer?.isActive ?? false)) return;
      await _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onUpdate(UpdateValidationJob event, Emitter<ValidationState> emit) async {
    if (!(_timeoutTimer?.isActive ?? false)) return;

    try {
      final query = client.from("validation_jobs").select();
      final filtered = query.eq("id", event.id);
      final rows = await filtered.limit(1);

      if (!(_timeoutTimer?.isActive ?? false)) return;

      if (rows.isEmpty) {
        await _emitError(emit: emit, error: "Unable to find validation job");
        return;
      }

      final row = rows.first;
      final status = row["status"] as String;

      if (status == "working") {
        emit(const ValidationWorking());
        return;
      }

      if (status == "completed_valid") {
        await _cancelJob();
        final newState = ValidationCompleted(message: row["result_message"] as String, isValid: true);
        emit(newState);
      } else if (status == "completed_invalid") {
        await _cancelJob();
        final newState = ValidationCompleted(message: row["result_message"] as String, isValid: false);
        emit(newState);
      } else if (status == "errored") {
        await _emitError(emit: emit, error: row["result_message"]);
      } else {
        await _emitError(emit: emit, error: "Unknown validation job status: $status");
      }
    } catch (error) {
      if (!(_timeoutTimer?.isActive ?? false)) return;
      await _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onError(ShowValidationError event, Emitter<ValidationState> emit) async {
    if (state is! ValidationWorking) return;
    await _emitError(emit: emit, error: event.message);
  }

  Future<void> _onReset(ResetValidation event, Emitter<ValidationState> emit) async {
    await _cancelJob();
    emit(const ValidationInitial());
  }

  Future<void> _cancelJob() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
  }

  Future<void> _emitError({required Emitter<ValidationState> emit, required dynamic error}) async {
    await _cancelJob();
    final newState = ValidationError(message: error.toString());
    emit(newState);
  }

  @override
  Future<void> close() async {
    await _cancelJob();
    return super.close();
  }
}
