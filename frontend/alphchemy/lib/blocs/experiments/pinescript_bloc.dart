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

const timeoutDuration = Duration(seconds: 30);

class PinescriptBloc extends Bloc<PinescriptEvent, PinescriptState> {
  final SupabaseClient client;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  Timer? _timeoutTimer;

  PinescriptBloc({required this.client}) : super(const PinescriptInitial()) {
    on<ConvertPinescript>(_onConvert);
    on<UpdatePinescriptJob>(_onUpdate);
    on<ShowPinescriptError>(_onError);
    on<ResetPinescript>(_onReset);
  }

  Future<void> _onConvert(ConvertPinescript event, Emitter<PinescriptState> emit) async {
    emit(const PinescriptWorking());
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(timeoutDuration, () {
      const event = ShowPinescriptError(message: "PineScript conversion timed out after 30 seconds");
      add(event);
    });

    try {
      final table = client.from("pinescript_jobs");
      final insert = table.insert({
        "experiment_id": event.experimentId,
        "fold_idx": event.foldIdx,
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
          final event = UpdatePinescriptJob(id: jobId);
          add(event);
        },
        onError: (Object error) {
          final event = ShowPinescriptError(message: error.toString());
          add(event);
        }
      );

      if (!(_timeoutTimer?.isActive ?? false)) {
        await _cancelJob();
        return;
      }

      // Safety net: query once now in case the worker finished before the
      // realtime subscription was ready (the UPDATE event would be missed).
      final initialCheck = UpdatePinescriptJob(id: jobId);
      add(initialCheck);
    } catch (error) {
      if (!(_timeoutTimer?.isActive ?? false)) return;
      await _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onUpdate(UpdatePinescriptJob event, Emitter<PinescriptState> emit) async {
    if (!(_timeoutTimer?.isActive ?? false)) return;

    try {
      final query = client.from("pinescript_jobs").select();
      final filtered = query.eq("id", event.id);
      final rows = await filtered.limit(1);

      if (!(_timeoutTimer?.isActive ?? false)) return;

      if (rows.isEmpty) {
        await _emitError(emit: emit, error: "Unable to find pinescript job");
        return;
      }

      final row = rows.first;
      final status = row["status"] as String;

      if (status == "working") {
        emit(const PinescriptWorking());
        return;
      }

      if (status == "completed") {
        await _cancelJob();
        final newState = PinescriptCompleted(pinescript: row["pinescript"] as String);
        emit(newState);
      } else if (status == "errored") {
        await _emitError(emit: emit, error: row["error_message"]);
      } else {
        await _emitError(emit: emit, error: "Unknown PineScript job status: $status");
      }
    } catch (error) {
      if (!(_timeoutTimer?.isActive ?? false)) return;
      await _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onError(ShowPinescriptError event, Emitter<PinescriptState> emit) async {
    if (state is! PinescriptWorking) return;
    await _emitError(emit: emit, error: event.message);
  }

  Future<void> _onReset(ResetPinescript event, Emitter<PinescriptState> emit) async {
    await _cancelJob();
    emit(const PinescriptInitial());
  }

  @override
  Future<void> close() async {
    await _cancelJob();
    return super.close();
  }

   Future<void> _cancelJob() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
  }

  Future<void> _emitError({required Emitter<PinescriptState> emit, required dynamic error}) async {
    await _cancelJob();
    final newState = PinescriptError(message: error.toString());
    emit(newState);
  }
}
