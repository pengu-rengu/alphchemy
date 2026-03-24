import 'package:alphchemy/blocs/experiment_generator_event.dart';
import 'package:alphchemy/blocs/experiment_generator_state.dart';
import 'package:alphchemy/model/experiment.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExperimentGeneratorBloc extends Bloc<ExperimentGeneratorEvent, ExperimentGeneratorState> {
  ExperimentGenerator? _generator;

  ExperimentGeneratorBloc() : super(const ExperimentGeneratorInitial()) {
    on<LoadExperimentGenerator>(_onLoad);
    on<SetExperimentGenerator>(_onSet);
  }

  void _onLoad(
    LoadExperimentGenerator event,
    Emitter<ExperimentGeneratorState> emit
  ) {
    emit(const ExperimentGeneratorLoading());
    if (_generator == null) {
      emit(const ExperimentGeneratorInitial());
      return;
    }
    emit(ExperimentGeneratorLoaded(generator: _generator!));
  }

  void _onSet(
    SetExperimentGenerator event,
    Emitter<ExperimentGeneratorState> emit
  ) {
    emit(const ExperimentGeneratorLoading());
    _generator = event.generator;
    emit(ExperimentGeneratorLoaded(generator: _generator!));
  }
}
