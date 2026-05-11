import "package:alphchemy/model/agent_system/agent_schema.dart";

class AgentSummary {
  final int id;
  final String title;
  final DateTime lastEdited;
  final AgentStatus status;
  final bool hasPendingPrompt;

  const AgentSummary({required this.id, required this.title, required this.lastEdited, required this.status, required this.hasPendingPrompt});

  factory AgentSummary.fromJson(Map<String, dynamic> json) {
    return AgentSummary(
      id: json["id"] as int,
      title: cleanAgentTitle(json["title"]),
      lastEdited: DateTime.parse(json["last_edited"] as String),
      status: AgentStatus.fromJson(json["status"]),
      hasPendingPrompt: json["user_prompt"] != null
    );
  }
}

String cleanAgentTitle(dynamic value) {
  final raw = value as String? ?? "";
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return "Untitled Agent";
  }

  return trimmed;
}
