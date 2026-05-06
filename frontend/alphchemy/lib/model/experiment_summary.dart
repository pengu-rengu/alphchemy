class ExperimentSummary {
  final String id;
  final String title;
  final DateTime createdAt;

  const ExperimentSummary({required this.id, required this.title, required this.createdAt});

  factory ExperimentSummary.fromJson(Map<String, dynamic> json) {
    return ExperimentSummary(
      id: json["id"] as String,
      title: json["title"] as String,
      createdAt: DateTime.parse(json["created_at"] as String)
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "created_at": createdAt.toIso8601String()
    };
  }
}
