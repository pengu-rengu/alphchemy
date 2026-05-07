import "package:alphchemy/model/experiment_data.dart";
import "package:alphchemy/model/experiment_summary.dart";
import "package:alphchemy/repositories/experiment_repository.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class ExperimentsEvent {
  const ExperimentsEvent();
}

class LoadExperiments extends ExperimentsEvent {
  const LoadExperiments();
}

class CreateExperiment extends ExperimentsEvent {
  final String id;

  const CreateExperiment({required this.id});
}

class DeleteExperiment extends ExperimentsEvent {
  final String id;

  const DeleteExperiment({required this.id});
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
  final ExperimentRepository repository;

  ExperimentsBloc({required this.repository})
      : super(const ExperimentsInitial()) {
    on<LoadExperiments>(_onLoad);
    on<CreateExperiment>(_onCreate);
    on<DeleteExperiment>(_onDelete);
  }

  Future<void> _onLoad(LoadExperiments event, Emitter<ExperimentsState> emit) async {
    try {
      final experiments = await repository.loadAll();
      emit(ExperimentsLoaded(experiments: experiments));
    } catch (err) {
      emit(ExperimentsError(message: err.toString()));
    }
  }

  Future<void> _onCreate(
    CreateExperiment event,
    Emitter<ExperimentsState> emit
  ) async {
    final defaultData = ExperimentData.blank();
    try {
      await repository.save(event.id, defaultData);
      final experiments = await repository.loadAll();
      emit(ExperimentsLoaded(experiments: experiments));
    } catch (err) {
      emit(ExperimentsError(message: err.toString()));
    }
  }

  Future<void> _onDelete(DeleteExperiment event, Emitter<ExperimentsState> emit) async {
    try {
      await repository.delete(event.id);
      final experiments = await repository.loadAll();
      emit(ExperimentsLoaded(experiments: experiments));
    } catch (err) {
      emit(ExperimentsError(message: err.toString()));
    }
  }
}
