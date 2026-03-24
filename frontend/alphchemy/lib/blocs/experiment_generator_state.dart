import 'package:alphchemy/model/experiment.dart';

sealed class ExperimentGeneratorState {
  const ExperimentGeneratorState();
}

class ExperimentGeneratorInitial extends ExperimentGeneratorState {
  const ExperimentGeneratorInitial();
}

class ExperimentGeneratorLoading extends ExperimentGeneratorState {
  const ExperimentGeneratorLoading();
}

class ExperimentGeneratorLoaded extends ExperimentGeneratorState {
  final ExperimentGenerator generator;

  const ExperimentGeneratorLoaded({required this.generator});
}

class ExperimentGeneratorError extends ExperimentGeneratorState {
  final String message;

  const ExperimentGeneratorError({required this.message});
}
