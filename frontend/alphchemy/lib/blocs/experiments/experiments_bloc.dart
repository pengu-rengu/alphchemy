import "package:alphchemy/model/experiment_summary.dart";
import "package:alphchemy/utils.dart";
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

class FilterExperiments extends ExperimentsEvent {
  final String filter;

  const FilterExperiments({required this.filter});
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
  final String filter;
  final int page;
  final bool hasMore;

  const ExperimentsLoaded({required this.summaries, this.errorMessage, required this.filter, required this.page, required this.hasMore});
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
      final filter = loaded == null ? "all" : loaded.filter;
      final page = loaded == null ? 0 : loaded.page;
      await _reload(emit: emit, page: page, filter: filter);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onFilter(FilterExperiments event, Emitter<ExperimentsState> emit) async {
    try {
      await _reload(emit: emit, page: 0, filter: event.filter);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onChangePage(ChangePage event, Emitter<ExperimentsState> emit) async {
    try {
      await _reload(emit: emit, page: event.page, filter: (state as ExperimentsLoaded).filter);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onDelete(DeleteExperiment event, Emitter<ExperimentsState> emit) async {
    try {
      final loaded = state as ExperimentsLoaded;
      final table = client.from("experiments");
      await table.delete().eq("id", event.id);

      await _reload(emit: emit, page: loaded.page, filter: loaded.filter);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onQueue(QueueExperiment event, Emitter<ExperimentsState> emit) async {
    try {
      final title = cleanTitle(event.title);
      final table = client.from("experiments");
      await table.insert( <String, dynamic>{
        "title": title,
        "source": event.source,
        "status": ExperimentStatus.queued.name
      });

      final loaded = state as ExperimentsLoaded;
      await _reload(emit: emit, page: loaded.page, filter: loaded.filter);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<(List<ExperimentSummary>, bool)> _loadSummaries({required int page, required String filter}) async {
    var query = client.from("experiments").select("id, last_edited, title, status");
    if (filter != "all") {
      query = query.eq("status", filter);
    }

    final ordered = query.order("last_edited");

    final start = page * pageSize;
    final rows = await ordered.range(start, start + pageSize);

    final hasMore = rows.length > pageSize;
    final limited = hasMore ? rows.sublist(0, pageSize) : rows;
    final summaries = limited.map(ExperimentSummary.fromJson).toList();

    return (summaries, hasMore);
  }

  Future<void> _reload({required Emitter<ExperimentsState> emit, required int page, required String filter}) async {
    var current = page;
    var (summaries, hasMore) = await _loadSummaries(page: current, filter: filter);

    while (summaries.isEmpty && current > 0) {
      current = current - 1;
      (summaries, hasMore) = await _loadSummaries(page: current, filter: filter);
    }

    final newState = ExperimentsLoaded(summaries: summaries, filter: filter, page: current, hasMore: hasMore);
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
        filter: loaded.filter,
        page: loaded.page,
        hasMore: loaded.hasMore
      );
    } else {
      newState = ExperimentsError(message: message);
    }

    emit(newState);
  }
}
