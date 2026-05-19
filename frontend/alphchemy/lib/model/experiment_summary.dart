enum ExperimentStatus {
  queued, running, completed, errored;

  const ExperimentStatus();

  factory ExperimentStatus.fromJson(dynamic value) {
    final rawStatus = value as String? ?? "queued";
    final status = rawStatus.toLowerCase();

    return switch (status) {
      "queued" => ExperimentStatus.queued,
      "running" => ExperimentStatus.running,
      "completed" => ExperimentStatus.completed,
      "errored" => ExperimentStatus.errored,
      _ => ExperimentStatus.queued
    };
  }
}

class ExperimentSummary {
  final int id;
  final DateTime createdAt;
  final String title;
  final ExperimentStatus status;
  final String? errorMessage;

  const ExperimentSummary({required this.id, required this.createdAt, required this.title, required this.status, required this.errorMessage});

  factory ExperimentSummary.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json["created_at"] as String);
    final title = json["title"] as String;
    final status = ExperimentStatus.fromJson(json["status"]);

    final results = json["results"];
    final errorMessage = results is Map<String, dynamic> ? results["error"] as String? : null;

    return ExperimentSummary(
      id: json["id"] as int,
      createdAt: createdAt,
      title: title,
      status: status,
      errorMessage: errorMessage
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "created_at": createdAt.toIso8601String(),
      "title": title,
      "status": status.name,
      "error_message": errorMessage
    };
  }
}
