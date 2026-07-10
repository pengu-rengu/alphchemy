import "package:alphchemy/model/notebook/notebook_summary.dart";
import "package:alphchemy/utils.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

sealed class NotebooksEvent {
  const NotebooksEvent();
}

class LoadNotebooks extends NotebooksEvent {
  const LoadNotebooks();
}

class CreateNotebook extends NotebooksEvent {
  final String title;
  final void Function(int id) onCreated;

  const CreateNotebook({required this.title, required this.onCreated});
}

class DeleteNotebook extends NotebooksEvent {
  final int id;

  const DeleteNotebook({required this.id});
}

sealed class NotebooksState {
  const NotebooksState();
}

class NotebooksInitial extends NotebooksState {
  const NotebooksInitial();
}

class NotebooksLoaded extends NotebooksState {
  final List<NotebookSummary> summaries;
  final String? errorMessage;

  const NotebooksLoaded({required this.summaries, this.errorMessage});
}

class NotebooksError extends NotebooksState {
  final String message;

  const NotebooksError({required this.message});
}

class NotebooksBloc extends Bloc<NotebooksEvent, NotebooksState> {
  final SupabaseClient client;

  NotebooksBloc({required this.client}) : super(const NotebooksInitial()) {
    on<LoadNotebooks>(_onLoad);
    on<CreateNotebook>(_onCreate);
    on<DeleteNotebook>(_onDelete);
  }

  Future<void> _onLoad(LoadNotebooks event, Emitter<NotebooksState> emit) async {
    try {
      await _loadAndEmit(emit: emit);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onCreate(CreateNotebook event, Emitter<NotebooksState> emit) async {
    try {
      final cleanedTitle = cleanTitle(event.title);
      final table = client.from("notebooks");
      final insert = table.insert({
        "title": cleanedTitle,
        "queries": <Map<String, dynamic>>[],
        "notes": <String>[],
        "status": NotebookStatus.idle.name
      });
      final row = await insert.select("id").single();
      event.onCreated(row["id"] as int);

      await _loadAndEmit(emit: emit);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onDelete(DeleteNotebook event, Emitter<NotebooksState> emit) async {
    try {
      final table = client.from("notebooks");
      await table.delete().eq("id", event.id);
      await _loadAndEmit(emit: emit);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _loadAndEmit({required Emitter<NotebooksState> emit}) async {
    final table = client.from("notebooks");
    final query = table.select("id, last_updated, title, status");
    final rows = await query.order("last_updated", ascending: false);

    final summaries = <NotebookSummary>[];
    for (final row in rows) {
      final summary = NotebookSummary.fromJson(row);
      summaries.add(summary);
    }

    final newState = NotebooksLoaded(summaries: summaries);
    emit(newState);
  }

  void _emitError({required Emitter<NotebooksState> emit, required Object error}) {
    final message = error.toString();
    late final NotebooksState newState;

    if (state is NotebooksLoaded) {
      newState = NotebooksLoaded(
        summaries: [...(state as NotebooksLoaded).summaries],
        errorMessage: message
      );
    } else {
      newState = NotebooksError(message: error.toString());
    }
    
    emit(newState);
  }
}
