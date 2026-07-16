import "package:alphchemy_app/model/experiment_summary.dart";
import "package:alphchemy_app/utils.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

sealed class ExperimentsEvent {
  const ExperimentsEvent();
}

class LoadExperiments extends ExperimentsEvent {
  const LoadExperiments();
}

class DeleteExperiment extends ExperimentsEvent {
  final int id;

  const DeleteExperiment({required this.id});
}

class QueueExperiment extends ExperimentsEvent {
  final String title;
  final String source;

  const QueueExperiment({required this.title, required this.source});
}

enum ExperimentStatusFilter {
  all,
  running,
  queued,
  completed,
  errored
}

enum ExperimentVisibilityFilter {
  all,
  private,
  public
}

class FilterExperiments extends ExperimentsEvent {
  final ExperimentStatusFilter statusFilter;
  final ExperimentVisibilityFilter visibilityFilter;

  const FilterExperiments({
    required this.statusFilter,
    required this.visibilityFilter
  });
}

class ChangePage extends ExperimentsEvent {
  final int page;

  const ChangePage({required this.page});
}

sealed class ExperimentsState {
  const ExperimentsState();
}

class ExperimentsInitial extends ExperimentsState {
  const ExperimentsInitial();
}

class ExperimentsLoaded extends ExperimentsState {
  final List<ExperimentSummary> summaries;
  final String? errorMessage;
  final ExperimentStatusFilter statusFilter;
  final ExperimentVisibilityFilter visibilityFilter;
  final int page;
  final bool hasMore;

  const ExperimentsLoaded({required this.summaries, this.errorMessage, required this.statusFilter, required this.visibilityFilter, required this.page, required this.hasMore});
}

class ExperimentsError extends ExperimentsState {
  final String message;

  const ExperimentsError({required this.message});
}

const pageSize = 50;

class ExperimentsBloc extends Bloc<ExperimentsEvent, ExperimentsState> {

  final SupabaseClient client;

  ExperimentsBloc({required this.client})
      : super(const ExperimentsInitial()) {
    on<LoadExperiments>(_onLoad);
    on<DeleteExperiment>(_onDelete);
    on<QueueExperiment>(_onQueue);
    on<FilterExperiments>(_onFilter);
    on<ChangePage>(_onChangePage);
  }

  Future<void> _onLoad(LoadExperiments event, Emitter<ExperimentsState> emit) async {
    try {
      final loaded = state is ExperimentsLoaded ? state as ExperimentsLoaded : null;
      final statusFilter = loaded == null ? ExperimentStatusFilter.all : loaded.statusFilter;
      final visibilityFilter = loaded == null ? ExperimentVisibilityFilter.all : loaded.visibilityFilter;
      final page = loaded == null ? 0 : loaded.page;
      await _reload(emit: emit, page: page, statusFilter: statusFilter, visibilityFilter: visibilityFilter);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onFilter(FilterExperiments event, Emitter<ExperimentsState> emit) async {
    try {
      await _reload(emit: emit, page: 0, statusFilter: event.statusFilter, visibilityFilter: event.visibilityFilter);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onChangePage(ChangePage event, Emitter<ExperimentsState> emit) async {
    try {
      final loaded = state as ExperimentsLoaded;
      await _reload(emit: emit, page: event.page, statusFilter: loaded.statusFilter, visibilityFilter: loaded.visibilityFilter);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onDelete(DeleteExperiment event, Emitter<ExperimentsState> emit) async {
    try {
      final loaded = state as ExperimentsLoaded;
      final table = client.from("experiments");
      await table.delete().eq("id", event.id);

      await _reload(emit: emit, page: loaded.page, statusFilter: loaded.statusFilter, visibilityFilter: loaded.visibilityFilter);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onQueue(QueueExperiment event, Emitter<ExperimentsState> emit) async {
    try {
      final title = cleanTitle(event.title);
      final userId = _currentUserId();
      final table = client.from("experiments");
      await table.insert( <String, dynamic>{
        "title": title,
        "source": event.source,
        "status": ExperimentStatus.queued.name,
        "user_id": userId,
        "is_public": false
      });

      final loaded = state as ExperimentsLoaded;
      await _reload(emit: emit, page: loaded.page, statusFilter: loaded.statusFilter, visibilityFilter: loaded.visibilityFilter);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<(List<ExperimentSummary>, bool)> _loadSummaries({required int page, required ExperimentStatusFilter statusFilter, required ExperimentVisibilityFilter visibilityFilter}) async {
    final userId = _currentUserId();
    var query = client.from("experiments").select("id, last_updated, title, status, user_id, is_public");
    if (statusFilter != ExperimentStatusFilter.all) {
      query = query.eq("status", statusFilter.name);
    }
    if (visibilityFilter == ExperimentVisibilityFilter.private) {
      query = query.eq("user_id", userId);
      query = query.eq("is_public", false);
    }
    if (visibilityFilter == ExperimentVisibilityFilter.public) {
      query = query.eq("is_public", true);
    }

    final ordered = query.order("last_updated");

    final start = page * pageSize;
    final rows = await ordered.range(start, start + pageSize);

    final hasMore = rows.length > pageSize;
    final limited = hasMore ? rows.sublist(0, pageSize) : rows;
    final summaries = limited.map(ExperimentSummary.fromJson).toList();

    return (summaries, hasMore);
  }

  Future<void> _reload({required Emitter<ExperimentsState> emit, required int page, required ExperimentStatusFilter statusFilter, required ExperimentVisibilityFilter visibilityFilter}) async {
    var (summaries, hasMore) = await _loadSummaries(page: page, statusFilter: statusFilter, visibilityFilter: visibilityFilter);

    while (summaries.isEmpty && page > 0) {
      page -= 1;
      (summaries, hasMore) = await _loadSummaries(page: page, statusFilter: statusFilter, visibilityFilter: visibilityFilter);
    }

    final newState = ExperimentsLoaded(
      summaries: summaries,
      statusFilter: statusFilter,
      visibilityFilter: visibilityFilter,
      page: page,
      hasMore: hasMore
    );
    emit(newState);
  }

  void _emitError({required Emitter<ExperimentsState> emit, required Object error}) {
    final message = error.toString();
    late final ExperimentsState newState;

    if (state is ExperimentsLoaded) {
      final loaded = state as ExperimentsLoaded;
      newState = ExperimentsLoaded(
        summaries: [...loaded.summaries],
        errorMessage: message,
        statusFilter: loaded.statusFilter,
        visibilityFilter: loaded.visibilityFilter,
        page: loaded.page,
        hasMore: loaded.hasMore
      );
    } else {
      newState = ExperimentsError(message: message);
    }

    emit(newState);
  }

  String _currentUserId() {
    final user = client.auth.currentUser;
    if (user == null) throw StateError("Experiment access requires authentication");

    return user.id;
  }
}
