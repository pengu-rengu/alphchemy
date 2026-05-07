class ExperimentData {
  final Map<String, dynamic> experiment;

  const ExperimentData({required this.experiment});

  factory ExperimentData.fromJson(Map<String, dynamic> json) {
    final experiment = Map<String, dynamic>.from(json);
    experiment.remove("title");
    return ExperimentData(experiment: experiment);
  }

  factory ExperimentData.blank() {
    return const ExperimentData(experiment: {});
  }

  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(experiment);
    json.remove("title");
    return json;
  }
}
