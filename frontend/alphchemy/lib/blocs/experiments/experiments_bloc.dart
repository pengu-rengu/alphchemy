import "package:alphchemy/model/experiment/experiment.dart";
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
  final Experiment experiment;

  const QueueExperiment({required this.title, required this.experiment});
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

  const ExperimentsLoaded({required this.summaries, this.errorMessage});
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
  }

  Future<void> _onLoad(LoadExperiments event, Emitter<ExperimentsState> emit) async {
    try {
      final experiments = await _loadSummaries();
      final newState = ExperimentsLoaded(summaries: experiments);
      emit(newState);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
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
        "experiment": event.experiment.toJson(),
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
      newState = ExperimentsLoaded(
        summaries: [...(state as ExperimentsLoaded).summaries],
        errorMessage: message
      );
    } else {
      newState = ExperimentsError(message: message);
    }

    emit(newState);
  }

  void _emitLoaded({required Emitter<ExperimentsState> emit, required List<ExperimentSummary> summaries}) {
    final newState = ExperimentsLoaded(summaries: summaries);
    emit(newState);
  }
}
