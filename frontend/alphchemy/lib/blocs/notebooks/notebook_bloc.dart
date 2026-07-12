import "dart:async";

import "package:alphchemy/model/notebook/notebook.dart";
import "package:alphchemy/model/notebook/notebook_summary.dart";
import "package:alphchemy/model/notebook/query.dart";
import "package:alphchemy/utils.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

sealed class NotebookEvent {
  const NotebookEvent();
}

class SubscribeToNotebook extends NotebookEvent {
  final int id;

  const SubscribeToNotebook({required this.id});
}

class UpdateNotebook extends NotebookEvent {
  final int id;

  const UpdateNotebook({required this.id});
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
  final int idx;
  final Query query;
  final String note;

  const ReplaceTile({required this.idx, required this.query, required this.note});
}

class DeleteTile extends NotebookEvent {
  final int idx;

  const DeleteTile({required this.idx});
}

class AddTile extends NotebookEvent {
  const AddTile();
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

      final id = event.id;
      _streamSubscription = single.listen(
        (rows) {
          final event = UpdateNotebook(id: id);
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

  Future<void> _onUpdate(UpdateNotebook event, Emitter<NotebookState> emit) async {
    try {
      final table = client.from("notebooks");
      final owned = table.select().eq("user_id", _currentUserId());
      final filtered = owned.eq("id", event.id);
      final rows = await filtered.limit(1);

      if (rows.isEmpty) {
        _emitError(emit: emit, error: "Unable to find notebook");
        return;
      }

      final row = rows.first;
      final notebook = Notebook.fromJson(row);
      _emitLoaded(emit: emit, notebook: notebook, stale: false, errorMessage: row["error_message"] as String?);
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
      newNotebook.queries[event.idx] = event.query;
      newNotebook.notes[event.idx] = event.note;

      _emitLoaded(emit: emit, notebook: newNotebook);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onDeleteTile(DeleteTile event, Emitter<NotebookState> emit) {
    if (state is! NotebookLoaded) return;
    try {
      final newNotebook = _copyNotebook();
      newNotebook.queries.removeAt(event.idx);
      newNotebook.notes.removeAt(event.idx);

      _emitLoaded(emit: emit, notebook: newNotebook);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onAddTile(AddTile event, Emitter<NotebookState> emit) {
    if (state is! NotebookLoaded) return;
    try {
      final newNotebook = _copyNotebook();
      final query = Query(
        query: "",
        results: null
      );
      newNotebook.queries.add(query);
      newNotebook.notes.add("");

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
        "status": "working",
        "error_message": null,
        "last_updated": "now"
      });
      final owned = update.eq("user_id",  _currentUserId());
      await owned.eq("id", newNotebook.id);
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

  String _currentUserId() {
    final user = client.auth.currentUser;
    if (user == null) throw StateError("Notebook access requires authentication");

    return user.id;
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}
