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
  final DateTime lastEdited;
  final String title;
  final ExperimentStatus status;
  final String? errorMessage;

  const ExperimentSummary({required this.id, required this.lastEdited, required this.title, required this.status, required this.errorMessage});

  factory ExperimentSummary.fromJson(Map<String, dynamic> json) {
    final lastEdited = DateTime.parse(json["last_edited"] as String);
    final title = json["title"] as String;
    final status = ExperimentStatus.fromJson(json["status"]);

    final results = json["results"];
    final errorMessage = results is Map<String, dynamic> ? results["error"] as String? : null;

    return ExperimentSummary(
      id: json["id"] as int,
      lastEdited: lastEdited, // Delete?
      title: title,
      status: status,
      errorMessage: errorMessage
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "last_edited": lastEdited.toIso8601String(),
      "title": title,
      "status": status.name,
      "error_message": errorMessage
    };
  }
}
