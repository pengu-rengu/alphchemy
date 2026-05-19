import "package:alphchemy/model/agent_system/agent_schema.dart";

class AgentSummary {
  final int id;
  final String title;
  final DateTime lastEdited;
  final AgentStatus status;

  const AgentSummary({required this.id, required this.title, required this.lastEdited, required this.status});

  factory AgentSummary.fromJson(Map<String, dynamic> json) {
    final title = json["title"] as String;
    final lastEdited = DateTime.parse(json["last_edited"] as String);
    final status = AgentStatus.fromJson(json["status"]);

    return AgentSummary(
      id: json["id"] as int,
      title: title,
      lastEdited: lastEdited,
      status: status,
    );
  }
}