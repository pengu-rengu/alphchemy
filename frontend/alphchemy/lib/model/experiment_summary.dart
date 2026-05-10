enum ExperimentStatus {
  queued("queued"),
  running("running"),
  completed("completed"),
  errored("errored");

  final String label;

  const ExperimentStatus(this.label);

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

  bool get isCompleted {
    return this == ExperimentStatus.completed;
  }

  bool get isErrored {
    return this == ExperimentStatus.errored;
  }
}

class ExperimentSummary {
  final int id;
  final DateTime createdAt;
  final String title;
  final ExperimentStatus status;
  final String? errorMessage;

  const ExperimentSummary({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.status,
    this.errorMessage
  });

  factory ExperimentSummary.fromJson(Map<String, dynamic> json) {
    final id = json["id"] as int;
    final rawCreatedAt = json["created_at"] as String;
    final rawTitle = json["title"] as String?;
    final title = _titleFromJson(rawTitle);
    final errorMessage = _errorMessageFromJson(json["results"]);

    return ExperimentSummary(
      id: id,
      createdAt: DateTime.parse(rawCreatedAt),
      title: title,
      status: ExperimentStatus.fromJson(json["status"]),
      errorMessage: errorMessage
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "created_at": createdAt.toIso8601String(),
      "title": title,
      "status": status.label,
      "error_message": errorMessage
    };
  }

  static String _titleFromJson(String? value) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) {
      return "Untitled Experiment";
    }

    return trimmed;
  }

  static String? _errorMessageFromJson(dynamic value) {
    if (value is! Map) {
      return null;
    }

    final json = Map<String, dynamic>.from(value);
    return json["error"] as String?;
  }
}
