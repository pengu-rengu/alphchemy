enum ExperimentStatus {
  queued, running, completed, errored;

  const ExperimentStatus();

  factory ExperimentStatus.fromJson(dynamic value) {
    return switch (value) {
      "queued" => ExperimentStatus.queued,
      "running" => ExperimentStatus.running,
      "completed" => ExperimentStatus.completed,
      "errored" => ExperimentStatus.errored,
      _ => throw StateError("invalid experiment status: $value")
    };
  }
}

class ExperimentSummary {
  final int id;
  final DateTime lastUpdated;
  final String title;
  final ExperimentStatus status;
  final String? userId;
  final bool isPublic;

  const ExperimentSummary({required this.id, required this.lastUpdated, required this.title, required this.status, required this.userId, required this.isPublic});

  factory ExperimentSummary.fromJson(Map<String, dynamic> json) {
    final lastUpdated = DateTime.parse(json["last_updated"] as String);
    final title = json["title"] as String;
    final status = ExperimentStatus.fromJson(json["status"]);

    return ExperimentSummary(
      id: json["id"] as int,
      lastUpdated: lastUpdated,
      title: title,
      status: status,
      userId: json["user_id"] as String?,
      isPublic: json["is_public"] as bool
    );
  }
}
