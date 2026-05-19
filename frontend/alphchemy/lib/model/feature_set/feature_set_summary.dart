enum FeatureSetStatus {
  idle, working, fulfilled, errored;

  factory FeatureSetStatus.fromJson(dynamic value) {
    return switch (value) {
      "idle" => FeatureSetStatus.idle,
      "working" => FeatureSetStatus.working,
      "fulfilled" => FeatureSetStatus.fulfilled,
      "errored" => FeatureSetStatus.errored,
      _ => FeatureSetStatus.idle
    };
  }
}

class FeatureSetSummary {
  final int id;
  final DateTime lastEdited;
  final String title;
  final FeatureSetStatus status;

  const FeatureSetSummary({required this.id, required this.lastEdited, required this.title, required this.status});

  factory FeatureSetSummary.fromJson(Map<String, dynamic> json) {
    final lastEdited = DateTime.parse(json["last_edited"] as String);
    final title = json["title"] as String;
    final status = FeatureSetStatus.fromJson(json["status"]);

    return FeatureSetSummary(
      id: json["id"] as int,
      lastEdited: lastEdited,
      title: title,
      status: status
    );
  }
}
