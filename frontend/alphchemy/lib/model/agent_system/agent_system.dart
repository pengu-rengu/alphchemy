import "package:alphchemy/model/agent_system/agent_context.dart";
import "package:alphchemy/model/agent_system/agent_schema.dart";

class AgentSystem {
  final int id;
  final String title;
  final DateTime lastEdited;
  final List<String> agentIds;
  final AgentContexts contexts;
  final AgentStatus status;
  final String? userPrompt;

  const AgentSystem({required this.id, required this.title, required this.lastEdited, required this.agentIds, required this.contexts, required this.status, required this.userPrompt});

  factory AgentSystem.fromJson(Map<String, dynamic> json) {
    final agentIds = <String>[];
    final schemaJson = json["schema"] as Map<String, dynamic>;
    final agentsJson = schemaJson["agents"] as List<dynamic>;
    for (final agentItem in agentsJson) {
      final agentJson = agentItem as Map<String, dynamic>;
      final agentId = agentJson["id"] as String;
      agentIds.add(agentId);
    }

    final lastEdited = DateTime.parse(json["last_edited"] as String);
    final status = AgentStatus.fromJson(json["status"]);
    final userPrompt = json["user_prompt"] as String?;

    final contextsItem = (json["state"] as Map<String, dynamic>)["agent_contexts"];
    final contexts = AgentContexts.fromJson(contextsItem as Map<String, dynamic>, agentIds);

    return AgentSystem(
      id: json["id"] as int,
      title: json["title"] as String,
      lastEdited: lastEdited,
      agentIds: agentIds,
      contexts: contexts,
      status: status,
      userPrompt: userPrompt
    );
  }

  AgentSystem copyWith({
    String? title,
    List<String>? agentIds,
    AgentContexts? contexts,
    DateTime? lastEdited,
    AgentStatus? status,
    String? userPrompt
  }) {
    final nextAgentIds = agentIds ?? this.agentIds;
    final fixedAgentIds = List<String>.unmodifiable(nextAgentIds);

    return AgentSystem(
      id: id,
      title: title ?? this.title,
      lastEdited: lastEdited ?? this.lastEdited,
      agentIds: fixedAgentIds,
      contexts: contexts ?? this.contexts,
      status: status ?? this.status,
      userPrompt: userPrompt ?? this.userPrompt
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "last_edited": lastEdited.toIso8601String(),
      "status": status.name,
      "user_prompt": userPrompt
    };
  }
}
