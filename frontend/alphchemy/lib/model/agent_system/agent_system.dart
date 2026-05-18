import "package:alphchemy/model/agent_system/agent_contexts.dart";
import "package:alphchemy/model/agent_system/agent_schema.dart";
import "package:alphchemy/model/agent_system/submission.dart";

class AgentSystem {
  final int id;
  final String title;
  final DateTime lastEdited;
  final List<String> agentIds;
  final AgentContexts contexts;
  final AgentStatus status;
  final String? userPrompt;
  final List<Submission> submissions;

  const AgentSystem({required this.id, required this.title, required this.lastEdited, required this.agentIds, required this.contexts, required this.status, required this.userPrompt, required this.submissions});

  static List<String> _parseAgentIds(Map<String, dynamic> schemaJson) {
    final agentIds = <String>[];
    final agentsJson = schemaJson["agents"] as List<dynamic>;
    for (final agentItem in agentsJson) {
      final agentJson = agentItem as Map<String, dynamic>;
      agentIds.add(agentJson["id"] as String);
    }
    return agentIds;
  }

  static List<Submission> _parseSubmissions(List<dynamic> submissionsJson) {
    Submission submissionFromJson(dynamic item) => Submission.fromJson(item as Map<String, dynamic>);
    return submissionsJson.map(submissionFromJson).toList();
  }

  static AgentContexts _parseContexts(Map<String, dynamic> stateJson, List<String> agentIds) {
    return AgentContexts.fromJson(stateJson["agent_contexts"] as Map<String, dynamic>, agentIds);
  }

  factory AgentSystem.fromJson(Map<String, dynamic> json) {
    final agentIds = _parseAgentIds(json["schema"] as Map<String, dynamic>);
    final contexts = _parseContexts(json["state"] as Map<String, dynamic>, agentIds);
    final submissions = _parseSubmissions(json["submissions"] as List<dynamic>);
    final lastEdited = DateTime.parse(json["last_edited"] as String);
    final status = AgentStatus.fromJson(json["status"]);

    return AgentSystem(
      id: json["id"] as int,
      title: json["title"] as String,
      lastEdited: lastEdited,
      agentIds: agentIds,
      contexts: contexts,
      status: status,
      userPrompt: json["user_prompt"] as String?,
      submissions: submissions
    );
  }

  AgentSystem copyFromJson(Map<String, dynamic> json) {
    final schemaJson = json["schema"] as Map<String, dynamic>?;
    final stateJson = json["state"] as Map<String, dynamic>?;
    final submissionsJson = json["submissions"] as List<dynamic>?;
    final lastEditedJson = json["last_edited"] as String?;
    final statusJson = json["status"] as String?;

    final newAgentIds = schemaJson == null ? [...agentIds] : _parseAgentIds(schemaJson);
    final newContexts = stateJson == null ? contexts : _parseContexts(stateJson, newAgentIds);
    final newLastEdited = lastEditedJson == null ?  lastEdited.copyWith() : DateTime.parse(lastEditedJson);
    final newStatus = statusJson == null ? status : AgentStatus.fromJson(statusJson);
    final newUserPrompt = json["user_prompt"] ?? userPrompt;
    final newSubmissions = submissionsJson == null ? [...submissions] : _parseSubmissions(json["submissions"] as List<dynamic>);
    
    return AgentSystem(
      id: id, 
      title: json["title"] ?? title,
      lastEdited: newLastEdited, 
      agentIds: newAgentIds,
      contexts: newContexts,
      status: newStatus,
      userPrompt: newUserPrompt,
      submissions: newSubmissions
    );
  }
}
