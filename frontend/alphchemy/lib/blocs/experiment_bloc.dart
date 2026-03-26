import "package:alphchemy/objects/experiment.dart";
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ExperimentEvent {
  const ExperimentEvent();
}

class LoadExperiment extends ExperimentEvent {
  const LoadExperiment();
}

class SetExperiment extends ExperimentEvent {
  final Experiment experiment;

  const SetExperiment({required this.experiment});
}

sealed class ExperimentState {
  const ExperimentState();
}

class ExperimentInitial extends ExperimentState {
  const ExperimentInitial();
}

class ExperimentLoading extends ExperimentState {
  const ExperimentLoading();
}

class ExperimentLoaded extends ExperimentState {
  final Experiment experiment;

  const ExperimentLoaded({required this.experiment});
}

class ExperimentError extends ExperimentState {
  final String message;

  const ExperimentError({required this.message});
}

class ExperimentBloc extends Bloc<ExperimentEvent, ExperimentState> {
  Experiment? _experiment;

  ExperimentBloc() : super(const ExperimentInitial()) {
    on<LoadExperiment>((LoadExperiment event, Emitter<ExperimentState> emit) {
      emit(const ExperimentLoading());
      if (_experiment == null) {
        emit(const ExperimentInitial());
        return;
      }
      emit(ExperimentLoaded(experiment: _experiment!));
    });
    on<SetExperiment>((SetExperiment event, Emitter<ExperimentState> emit) {
      emit(const ExperimentLoading());
      _experiment = event.experiment;
      emit(ExperimentLoaded(experiment: _experiment!));
    });
  }
}
