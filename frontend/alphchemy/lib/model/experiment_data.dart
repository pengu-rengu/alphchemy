class ExperimentData {
  final Map<String, dynamic> experiment;

  const ExperimentData({required this.experiment});

  factory ExperimentData.fromJson(Map<String, dynamic> json) {
    return ExperimentData(experiment: json);
  }

  factory ExperimentData.blank(String title) {
    return ExperimentData(experiment: {"title": title});
  }

  Map<String, dynamic> toJson() {
    return experiment;
  }
}
