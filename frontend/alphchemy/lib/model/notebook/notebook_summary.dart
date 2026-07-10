enum NotebookStatus {
  idle, working, errored;

  factory NotebookStatus.fromJson(dynamic value) {
    return switch (value) {
      "idle" => NotebookStatus.idle,
      "working" => NotebookStatus.working,
      "errored" => NotebookStatus.errored,
      _ => throw StateError("invalid notebook status: $value")
    };
  }
}

class NotebookSummary {
  final int id;
  final DateTime lastUpdated;
  final String title;
  final NotebookStatus status;

  const NotebookSummary({required this.id, required this.lastUpdated, required this.title, required this.status});

  factory NotebookSummary.fromJson(Map<String, dynamic> json) {
    final lastUpdated = DateTime.parse(json["last_updated"] as String);
    final title = json["title"] as String;
    final status = NotebookStatus.fromJson(json["status"]);

    return NotebookSummary(
      id: json["id"] as int,
      lastUpdated: lastUpdated,
      title: title,
      status: status
    );
  }
}
