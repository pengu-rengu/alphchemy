import "dart:convert";

//import "package:alphchemy/model/experiment/experiment.dart";
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
  //final Experiment experiment;
  final String experiment;

  const QueueExperiment({required this.title, required this.experiment});
}

class FilterExperiments extends ExperimentsEvent {
  final String filter;

  const FilterExperiments({required this.filter});
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

  const ExperimentsLoaded({required this.summaries, this.errorMessage, required this.filter});
}

class ExperimentsError extends ExperimentsState {
  final String message;

  const ExperimentsError({required this.message});
}

class ExperimentsBloc extends Bloc<ExperimentsEvent, ExperimentsState> {
  final SupabaseClient client;

  ExperimentsBloc({required this.client})
      : super(const ExperimentsInitial()) {
    on<LoadExperiments>(_onLoad);
    on<DeleteExperiment>(_onDelete);
    on<QueueExperiment>(_onQueue);
    on<FilterExperiments>(_onFilter);
  }

  Future<void> _onLoad(LoadExperiments event, Emitter<ExperimentsState> emit) async {
    try {
      final newState = ExperimentsLoaded(summaries:  await _loadSummaries(), filter: state is ExperimentsLoaded ? (state as ExperimentsLoaded).filter : "all");
      emit(newState);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onFilter(FilterExperiments event, Emitter<ExperimentsState> emit) {
    final loaded = state as ExperimentsLoaded;
    final newState = ExperimentsLoaded(summaries: loaded.summaries, errorMessage: loaded.errorMessage, filter: event.filter);
    emit(newState);
  }

  Future<void> _onDelete(DeleteExperiment event, Emitter<ExperimentsState> emit) async {
    try {
      final table = client.from("experiments");
      await table.delete().eq("id", event.id);

      _emitLoaded(emit: emit, summaries: await _loadSummaries());
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onQueue(QueueExperiment event, Emitter<ExperimentsState> emit) async {
    try {
      final title = cleanTitle(event.title);
      final payload = <String, dynamic>{
        "title": title,
        //"experiment": event.experiment.toJson(),
        "experiment": jsonDecode(event.experiment),
        "status": ExperimentStatus.queued.name
      };
      final table = client.from("experiments");
      await table.insert(payload);

      _emitLoaded(emit: emit, summaries: await _loadSummaries());
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<List<ExperimentSummary>> _loadSummaries() async {
    final query = client.from("experiments").select();
    final rows = await query.order("last_edited");
    final summaries = <ExperimentSummary>[];

    for (final row in rows) {
      final json = Map<String, dynamic>.from(row);
      final experiment = ExperimentSummary.fromJson(json);
      summaries.add(experiment);
    }

    return summaries;
  }

  void _emitError({required Emitter<ExperimentsState> emit, required Object error}) {
    final message = error.toString();
    late final ExperimentsState newState;

    if (state is ExperimentsLoaded) {
      final loaded = state as ExperimentsLoaded;
      newState = ExperimentsLoaded(
        summaries: [...loaded.summaries],
        errorMessage: message,
        filter: loaded.filter
      );
    } else {
      newState = ExperimentsError(message: message);
    }

    emit(newState);
  }

  void _emitLoaded({required Emitter<ExperimentsState> emit, required List<ExperimentSummary> summaries}) {
    final current = state;
    final filter = current is ExperimentsLoaded ? current.filter : "all";
    final newState = ExperimentsLoaded(summaries: summaries, filter: filter);
    emit(newState);
  }
}
