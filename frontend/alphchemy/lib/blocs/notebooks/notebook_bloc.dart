import "dart:async";

import "package:alphchemy/model/notebook/notebook.dart";
import "package:alphchemy/model/notebook/notebook_summary.dart";
import "package:alphchemy/model/notebook/query.dart";
import "package:alphchemy/utils.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:uuid/uuid.dart";

sealed class NotebookEvent {
  const NotebookEvent();
}

class SubscribeToNotebook extends NotebookEvent {
  final int id;

  const SubscribeToNotebook({required this.id});
}

class UpdateNotebook extends NotebookEvent {
  final Map<String, dynamic> row;

  const UpdateNotebook({required this.row});
}

class ShowNotebookError extends NotebookEvent {
  final String message;

  const ShowNotebookError({required this.message});
}

class RenameNotebook extends NotebookEvent {
  final String title;

  const RenameNotebook({required this.title});
}

class ReplaceTile extends NotebookEvent {
  final Query query;
  final String note;

  const ReplaceTile({required this.query, required this.note});
}

class DeleteTile extends NotebookEvent {
  final String tileId;

  const DeleteTile({required this.tileId});
}

class AddTile extends NotebookEvent {
  final bool left;

  const AddTile({required this.left});
}

class RequestNotebookData extends NotebookEvent {
  const RequestNotebookData();
}

sealed class NotebookState {
  const NotebookState();
}

class NotebookInitial extends NotebookState {
  const NotebookInitial();
}

class NotebookError extends NotebookState {
  final String message;

  const NotebookError({required this.message});
}

class NotebookLoaded extends NotebookState {
  final Notebook notebook;
  final bool stale;
  final String? errorMessage;

  const NotebookLoaded({required this.notebook, required this.stale, this.errorMessage});
}

class NotebookBloc extends Bloc<NotebookEvent, NotebookState> {
  final SupabaseClient client;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;

  NotebookBloc({required this.client}) : super(const NotebookInitial()) {
    on<SubscribeToNotebook>(_onSubscribe);
    on<UpdateNotebook>(_onUpdate);
    on<ShowNotebookError>(_onError);
    on<RenameNotebook>(_onRename);
    on<ReplaceTile>(_onReplaceTile);
    on<DeleteTile>(_onDeleteTile);
    on<AddTile>(_onAddTile);
    on<RequestNotebookData>(_onRequest);
  }

  Future<void> _onSubscribe(SubscribeToNotebook event, Emitter<NotebookState> emit) async {
    await _streamSubscription?.cancel();

    try {
      final table = client.from("notebooks");
      final stream = table.stream(primaryKey: ["id"]);
      final filtered = stream.eq("id", event.id);
      final single = filtered.limit(1);

      _streamSubscription = single.listen(
        (rows) {
          late final NotebookEvent event;

          if (rows.isEmpty) {
            event = const ShowNotebookError(message: "Unable to find notebook");
          } else {
            event = UpdateNotebook(row: rows.first);
          }

          add(event);
        },
        onError: (error) {
          final event = ShowNotebookError(message: error.toString());
          add(event);
        }
      );
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onUpdate(UpdateNotebook event, Emitter<NotebookState> emit) {
    try {
      final notebook = Notebook.fromJson(event.row);
      _emitLoaded(emit: emit, notebook: notebook, stale: false, errorMessage: event.row["error_message"] as String?);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onError(ShowNotebookError event, Emitter<NotebookState> emit) {
    _emitError(emit: emit, error: event.message);
  }

  void _onRename(RenameNotebook event, Emitter<NotebookState> emit) {
    if (state is! NotebookLoaded) return;
    
    try {
      final newNotebook = _copyNotebook();
      newNotebook.title = cleanTitle(event.title);

      _emitLoaded(emit: emit, notebook: newNotebook);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onReplaceTile(ReplaceTile event, Emitter<NotebookState> emit) {
    if (state is! NotebookLoaded) return;

    try {
      final newNotebook = _copyNotebook();
      final idx = newNotebook.queries.indexWhere((entry) => entry.id == event.query.id);
      if (idx == -1) {
        _emitError(emit: emit, error: "Notebook tile not found");
        return;
      }

      newNotebook.queries[idx] = event.query;
      newNotebook.notes[event.query.id] = event.note;

      _emitLoaded(emit: emit, notebook: newNotebook);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onDeleteTile(DeleteTile event, Emitter<NotebookState> emit) {
    if (state is! NotebookLoaded) return;
    try {
      final newNotebook = _copyNotebook();
      newNotebook.queries.removeWhere((entry) => entry.id == event.tileId);
      newNotebook.notes.remove(event.tileId);
      newNotebook.layout.left.remove(event.tileId);
      newNotebook.layout.right.remove(event.tileId);

      _emitLoaded(emit: emit, notebook: newNotebook);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onAddTile(AddTile event, Emitter<NotebookState> emit) {
    if (state is! NotebookLoaded) return;
    try {
      final newNotebook = _copyNotebook();
      final id = const Uuid().v4();
      final query = Query(
        id: id,
        select: [],
        filters: [],
        results: null
      );
      newNotebook.queries.add(query);
      newNotebook.notes[id] = "";

      final layout = newNotebook.layout;
      if (event.left) {
        layout.left.add(id);
      } else {
        layout.right.add(id);
      }

      _emitLoaded(emit: emit, notebook: newNotebook);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onRequest(RequestNotebookData event, Emitter<NotebookState> emit) async {
    if (state is! NotebookLoaded) return;

    try {
      final newNotebook = _copyNotebook();

      newNotebook.status = NotebookStatus.working;
      for (final query in newNotebook.queries) {
        query.results = null;
      }

      _emitLoaded(emit: emit, notebook: newNotebook, stale: false);

      final queriesJson = newNotebook.queries.map((query) => query.toJson()).toList();

      final table = client.from("notebooks");
      final update = table.update({
        "title": newNotebook.title,
        "queries": queriesJson,
        "notes": newNotebook.notes,
        "layout": newNotebook.layout.toJson(),
        "status": "working",
        "error_message": null,
        "last_edited": DateTime.now().toUtc().toIso8601String()
      });
      await update.eq("id", newNotebook.id);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Notebook _copyNotebook() => (state as NotebookLoaded).notebook.copy();

  void _emitLoaded({required Emitter<NotebookState> emit, required Notebook notebook, bool stale = true, String? errorMessage}) {
    final newState = NotebookLoaded(
      notebook: notebook,
      stale: stale,
      errorMessage: errorMessage
    );
    emit(newState);
  }

  void _emitError({required Emitter<NotebookState> emit, required Object error}) {
    late final NotebookState newState;

    if (state is NotebookLoaded) {
      final loaded = state as NotebookLoaded;
      newState = NotebookLoaded(
        notebook: loaded.notebook.copy(),
        stale: loaded.stale,
        errorMessage: error.toString()
      );
    } else {
      newState = NotebookError(message: error.toString());
    }

    emit(newState);
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}
