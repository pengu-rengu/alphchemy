import 'package:alphchemy/model/experiment.dart';

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
