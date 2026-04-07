class GeneratorSummary {
  final String id;
  final String title;
  final DateTime createdAt;

  const GeneratorSummary({required this.id, required this.title, required this.createdAt});

  factory GeneratorSummary.fromJson(Map<String, dynamic> json) {
    return GeneratorSummary(
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
