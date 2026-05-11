import "package:alphchemy/model/agent_system/agent_schema.dart";
import "package:alphchemy/model/agent_system/agent_summary.dart";

class AgentSystem {
  final int id;
  final String title;
  final DateTime lastEdited;
  final AgentSystemSchema schema;
  final Map<String, dynamic>? state;
  final AgentStatus status;
  final String? userPrompt;

  const AgentSystem({required this.id, required this.title, required this.lastEdited, required this.schema, required this.state, required this.status, required this.userPrompt});

  factory AgentSystem.fromJson(Map<String, dynamic> json) {
    final schemaJson = json["schema"] as Map<String, dynamic>;
    final stateJson = json["state"] as Map<String, dynamic>?;

    return AgentSystem(
      id: json["id"] as int,
      title: cleanAgentTitle(json["title"]),
      lastEdited: DateTime.parse(json["last_edited"] as String),
      schema: AgentSystemSchema.fromJson(schemaJson),
      state: stateJson,
      status: AgentStatus.fromJson(json["status"]),
      userPrompt: json["user_prompt"] as String?
    );
  }

  AgentSystem copyWith({
    String? title,
    AgentSystemSchema? schema,
    Map<String, dynamic>? state,
    DateTime? lastEdited,
    AgentStatus? status,
    String? userPrompt
  }) {
    return AgentSystem(
      id: id,
      title: title ?? this.title,
      lastEdited: lastEdited ?? this.lastEdited,
      schema: schema ?? this.schema,
      state: state ?? this.state,
      status: status ?? this.status,
      userPrompt: userPrompt ?? this.userPrompt
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "last_edited": lastEdited.toIso8601String(),
      "schema": schema.toJson(),
      "state": state,
      "status": status.name,
      "user_prompt": userPrompt
    };
  }
}
