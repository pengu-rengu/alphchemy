class ExperimentSummary {
  final String id;
  final DateTime createdAt;

  const ExperimentSummary({required this.id, required this.createdAt});

  factory ExperimentSummary.fromJson(Map<String, dynamic> json) {
    return ExperimentSummary(
      id: json["id"] as String,
      createdAt: DateTime.parse(json["created_at"] as String)
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "created_at": createdAt.toIso8601String()
    };
  }
}
