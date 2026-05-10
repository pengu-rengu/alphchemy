import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/experiment_summary.dart";
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
  final Map<String, dynamic> data;

  const QueueExperiment({required this.title, required this.data});
}

sealed class ExperimentsState {
  const ExperimentsState();
}

class ExperimentsInitial extends ExperimentsState {
  const ExperimentsInitial();
}

class ExperimentsLoaded extends ExperimentsState {
  final List<ExperimentSummary> experiments;

  const ExperimentsLoaded({required this.experiments});
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
      final experiments = await _loadExperiments();
      final newState = ExperimentsLoaded(experiments: experiments);
      emit(newState);
    } catch (err) {
      final message = err.toString();
      final newState = ExperimentsError(message: message);
      emit(newState);
    }
  }

  Future<void> _onDelete(DeleteExperiment event, Emitter<ExperimentsState> emit) async {
    try {
      await _deleteExperiment(event.id);
      final experiments = await _loadExperiments();
      final newState = ExperimentsLoaded(experiments: experiments);
      emit(newState);
    } catch (err) {
      final message = err.toString();
      final newState = ExperimentsError(message: message);
      emit(newState);
    }
  }

  Future<void> _onQueue(QueueExperiment event, Emitter<ExperimentsState> emit) async {
    try {
      await _queueExperiment(title: event.title, data: event.data);
      final experiments = await _loadExperiments();
      final newState = ExperimentsLoaded(experiments: experiments);
      emit(newState);
    } catch (err) {
      final message = err.toString();
      final newState = ExperimentsError(message: message);
      emit(newState);
    }
  }

  Future<List<ExperimentSummary>> _loadExperiments() async {
    final table = client.from("experiments");
    final query = table.select("id, created_at, title, status, results");
    final rows = await query.order("created_at");
    final experiments = <ExperimentSummary>[];

    for (final row in rows) {
      final json = Map<String, dynamic>.from(row);
      final experiment = ExperimentSummary.fromJson(json);
      experiments.add(experiment);
    }

    return experiments;
  }

  Future<void> _queueExperiment({
    required String title,
    required Map<String, dynamic> data
  }) async {
    final experiment = cleanExperimentJson(data);
    final cleanTitle = _cleanTitle(title);
    final status = ExperimentStatus.queued.label;
    final payload = <String, dynamic>{
      "title": cleanTitle,
      "experiment": experiment,
      "status": status
    };
    final table = client.from("experiments");
    final insert = table.insert(payload);
    final query = insert.select("id, created_at, title, status");
    await query.single();
  }

  Future<void> _deleteExperiment(int id) async {
    final table = client.from("experiments");
    final delete = table.delete();
    final filtered = delete.eq("id", id);
    await filtered;
  }

  String _cleanTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return "Untitled Experiment";
    }

    return trimmed;
  }
}
