import 'package:alphchemy/model/experiment.dart';

sealed class ExperimentGeneratorEvent {
  const ExperimentGeneratorEvent();
}

class LoadExperimentGenerator extends ExperimentGeneratorEvent {
  const LoadExperimentGenerator();
}

class SetExperimentGenerator extends ExperimentGeneratorEvent {
  final ExperimentGenerator generator;

  const SetExperimentGenerator({required this.generator});
}
