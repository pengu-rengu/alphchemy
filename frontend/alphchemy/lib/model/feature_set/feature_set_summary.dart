enum FeatureSetStatus {
  idle("idle"),
  working("working"),
  fulfilled("fulfilled"),
  errored("errored");

  final String label;

  const FeatureSetStatus(this.label);

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
    final id = json["id"] as int;
    final rawLastEdited = json["last_edited"] as String;

    return FeatureSetSummary(
      id: id,
      lastEdited: DateTime.parse(rawLastEdited),
      title: json["title"] as String,
      status: FeatureSetStatus.fromJson(json["status"])
    );
  }
}
