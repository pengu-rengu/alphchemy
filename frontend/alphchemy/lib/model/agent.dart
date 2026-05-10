import "package:alphchemy/model/agent_summary.dart";
import "package:alphchemy/model/agent_status.dart";
import "package:alphchemy/model/agent_system.dart";
import "package:alphchemy/model/agents_state.dart";

const Object _copyUnset = Object();

class Agent {
  final int id;
  final String title;
  final DateTime lastEdited;
  final AgentSystemSchema schema;
  final AgentsState? state;
  final AgentStatus status;
  final String? userPrompt;

  const Agent({
    required this.id,
    required this.title,
    required this.lastEdited,
    required this.schema,
    required this.state,
    required this.status,
    required this.userPrompt
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    final schemaJson = json["schema"] as Map<String, dynamic>;
    final stateRaw = json["state"];
    final stateJson = stateRaw is Map<String, dynamic> ? stateRaw : null;
    final title = _titleFromJson(json["title"]);
    return Agent(
      id: json["id"] as int,
      title: title,
      lastEdited: DateTime.parse(json["last_edited"] as String),
      schema: AgentSystemSchema.fromJson(schemaJson),
      state: stateJson == null ? null : AgentsState.fromJson(stateJson),
      status: AgentStatus.fromJson(json["status"]),
      userPrompt: json["user_prompt"] as String?
    );
  }

  AgentSummary get summary {
    return AgentSummary(
      id: id,
      title: title,
      lastEdited: lastEdited,
      status: status,
      hasPendingPrompt: userPrompt != null
    );
  }

  Agent copyWith({
    String? title,
    AgentSystemSchema? schema,
    Object? state = _copyUnset,
    DateTime? lastEdited,
    AgentStatus? status,
    Object? userPrompt = _copyUnset
  }) {
    final nextState = state == _copyUnset ? this.state : state as AgentsState?;
    final nextPrompt = userPrompt == _copyUnset ? this.userPrompt : userPrompt as String?;

    return Agent(
      id: id,
      title: title ?? this.title,
      lastEdited: lastEdited ?? this.lastEdited,
      schema: schema ?? this.schema,
      state: nextState,
      status: status ?? this.status,
      userPrompt: nextPrompt
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "last_edited": lastEdited.toIso8601String(),
      "schema": schema.toJson(),
      "state": state?.toJson(),
      "status": status.label,
      "user_prompt": userPrompt
    };
  }

  static String _titleFromJson(dynamic value) {
    final trimmed = (value as String? ?? "").trim();
    if (trimmed.isEmpty) {
      return "Untitled Agent";
    }

    return trimmed;
  }
}
