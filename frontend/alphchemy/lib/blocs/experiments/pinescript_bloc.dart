import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

sealed class PinescriptEvent {
  const PinescriptEvent();
}

class ConvertPinescript extends PinescriptEvent {
  final int experimentId;
  final int foldIdx;

  const ConvertPinescript({
    required this.experimentId,
    required this.foldIdx
  });
}

class UpdatePinescriptJob extends PinescriptEvent {
  final int id;

  const UpdatePinescriptJob({required this.id});
}

class ShowPinescriptError extends PinescriptEvent {
  final String message;

  const ShowPinescriptError({required this.message});
}

class ResetPinescript extends PinescriptEvent {
  const ResetPinescript();
}

sealed class PinescriptState {
  const PinescriptState();
}

class PinescriptInitial extends PinescriptState {
  const PinescriptInitial();
}

class PinescriptWorking extends PinescriptState {
  const PinescriptWorking();
}

class PinescriptCompleted extends PinescriptState {
  final String pinescript;

  const PinescriptCompleted({required this.pinescript});
}

class PinescriptError extends PinescriptState {
  final String message;

  const PinescriptError({required this.message});
}

class PinescriptBloc extends Bloc<PinescriptEvent, PinescriptState> {
  final SupabaseClient client;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;

  PinescriptBloc({required this.client}) : super(const PinescriptInitial()) {
    on<ConvertPinescript>(_onConvert);
    on<UpdatePinescriptJob>(_onUpdate);
    on<ShowPinescriptError>(_onError);
    on<ResetPinescript>(_onReset);
  }

  Future<void> _onConvert(ConvertPinescript event, Emitter<PinescriptState> emit) async {
    emit(const PinescriptWorking());

    try {
      final table = client.from("pinescript_jobs");
      final insert = table.insert({
        "experiment_id": event.experimentId,
        "fold_idx": event.foldIdx,
        "status": "working"
      });
      final jobId = (await insert.select("id").single())["id"] as int;

      await _streamSubscription?.cancel();
      final stream = table.stream(primaryKey: ["id"]);
      final filtered = stream.eq("id", jobId);
      final single = filtered.limit(1);

      _streamSubscription = single.listen(
        (rows) {
          final event = UpdatePinescriptJob(id: jobId);
          add(event);
        },
        onError: (Object error) {
          final event = ShowPinescriptError(message: error.toString());
          add(event);
        }
      );

      // Safety net: query once now in case the worker finished before the
      // realtime subscription was ready (the UPDATE event would be missed).
      final initialCheck = UpdatePinescriptJob(id: jobId);
      add(initialCheck);
    } catch (error) {
      final newState = PinescriptError(message: error.toString());
      emit(newState);
    }
  }

  Future<void> _onUpdate(UpdatePinescriptJob event, Emitter<PinescriptState> emit) async {
    try {
      final query = client.from("pinescript_jobs").select();
      final filtered = query.eq("id", event.id);
      final rows = await filtered.limit(1);

      if (rows.isEmpty) {
        _emitError(emit: emit, error: "Unable to find pinescript job");
        return;
      }

      final row = rows.first;
      final status = row["status"] as String;

      if (status == "working") {
        emit(const PinescriptWorking());
        return;
      }

      await _streamSubscription?.cancel();
      _streamSubscription = null;

      if (status == "completed") {
        final newState = PinescriptCompleted(pinescript: row["pinescript"] as String);
        emit(newState);
      } else if (status == "errored") {
        _emitError(emit: emit, error: row["error_message"]);
      } else {
        _emitError(emit: emit, error: "Unknown PineScript job status: $status");
      }
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onError(ShowPinescriptError event, Emitter<PinescriptState> emit) {
    _emitError(emit: emit, error: event.message);
  }

  void _onReset(ResetPinescript event, Emitter<PinescriptState> emit) {
    emit(const PinescriptInitial());
  }

  void _emitError({required Emitter<PinescriptState> emit, required dynamic error}) {
    final newState = PinescriptError(message: error.toString());
    emit(newState);
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}
