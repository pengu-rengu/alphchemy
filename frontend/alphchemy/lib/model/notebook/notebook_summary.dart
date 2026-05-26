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
  final DateTime lastEdited;
  final String title;
  final NotebookStatus status;

  const NotebookSummary({required this.id, required this.lastEdited, required this.title, required this.status});

  factory NotebookSummary.fromJson(Map<String, dynamic> json) {
    final lastEdited = DateTime.parse(json["last_edited"] as String);
    final title = json["title"] as String;
    final status = NotebookStatus.fromJson(json["status"]);

    return NotebookSummary(
      id: json["id"] as int,
      lastEdited: lastEdited,
      title: title,
      status: status
    );
  }
}
