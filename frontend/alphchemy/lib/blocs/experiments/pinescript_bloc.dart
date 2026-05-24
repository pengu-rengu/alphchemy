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
  final Map<String, dynamic> row;

  const UpdatePinescriptJob({required this.row});
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
    on<UpdatePinescriptJob>(_onUpdateJob);
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
      final row = await insert.select("id").single();
      final jobId = row["id"] as int;

      await _subscribe(jobId);
    } catch (error) {
      emit(PinescriptError(message: error.toString()));
    }
  }

  Future<void> _subscribe(int jobId) async {
    await _streamSubscription?.cancel();

    final table = client.from("pinescript_jobs");
    final stream = table.stream(primaryKey: ["id"]);
    final filtered = stream.eq("id", jobId);
    final single = filtered.limit(1);

    _streamSubscription = single.listen(
      (rows) {
        if (rows.isEmpty) {
          return;
        }

        final event = UpdatePinescriptJob(row: rows.first);
        add(event);
      },
      onError: (Object error) {
        final event = ShowPinescriptError(message: error.toString());
        add(event);
      }
    );
  }

  Future<void> _onUpdateJob(UpdatePinescriptJob event, Emitter<PinescriptState> emit) async {
    final status = event.row["status"] as String?;

    if (status == "working") {
      emit(const PinescriptWorking());
      return;
    }

    await _streamSubscription?.cancel();
    _streamSubscription = null;

    if (status == "completed") {
      final pinescript = event.row["pinescript"] as String? ?? "";
      emit(PinescriptCompleted(pinescript: pinescript));
      return;
    }

    if (status == "errored") {
      final message = event.row["error_message"] as String? ?? "PineScript conversion failed";
      emit(PinescriptError(message: message));
      return;
    }

    final message = "Unknown PineScript job status: $status";
    emit(PinescriptError(message: message));
  }

  void _onError(ShowPinescriptError event, Emitter<PinescriptState> emit) {
    emit(PinescriptError(message: event.message));
  }

  void _onReset(ResetPinescript event, Emitter<PinescriptState> emit) {
    emit(const PinescriptInitial());
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}
