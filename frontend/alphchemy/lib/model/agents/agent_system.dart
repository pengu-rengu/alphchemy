import "package:alphchemy/model/agents/agent_contexts.dart";
import "package:alphchemy/model/agents/agent_schema.dart";
import "package:alphchemy/model/agents/submission.dart";

class AgentSystem {
  final int id;
  final String title;
  final DateTime lastEdited;
  final List<String> agentIds;
  final AgentContexts contexts;
  final Map<String, String> summaries;
  final AgentStatus status;
  final String? userPrompt;
  final List<Submission> submissions;

  const AgentSystem({required this.id, required this.title, required this.lastEdited, required this.agentIds, required this.contexts, required this.summaries, required this.status, required this.userPrompt, required this.submissions});

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

  static AgentContexts _parseContexts(Map<String, dynamic>? stateJson, List<String> agentIds) {
    if (stateJson == null) {
      return AgentContexts.fromJson(const <String, dynamic>{}, agentIds);
    }

    return AgentContexts.fromJson(stateJson["agent_contexts"] as Map<String, dynamic>, agentIds);
  }

  static Map<String, String> _parseSummaries(Map<String, dynamic>? stateJson, List<String> agentIds) {
    final summaries = <String, String>{for (final agentId in agentIds) agentId: ""};

    if (stateJson == null) {
      return summaries;
    }

    final summariesJson = stateJson["summaries"] as Map<String, dynamic>;
    for (final entry in summariesJson.entries) {
      summaries[entry.key] = entry.value as String;
    }

    return summaries;
  }

  factory AgentSystem.fromJson(Map<String, dynamic> json) {
    final agentIds = _parseAgentIds(json["schema"] as Map<String, dynamic>);
    final stateJson = json["state"] as Map<String, dynamic>?;
    final contexts = _parseContexts(stateJson, agentIds);
    final summaries = _parseSummaries(stateJson, agentIds);
    final submissions = _parseSubmissions(json["submissions"] as List<dynamic>);
    final lastEdited = DateTime.parse(json["last_edited"] as String);
    final status = AgentStatus.fromJson(json["status"]);

    return AgentSystem(
      id: json["id"] as int,
      title: json["title"] as String,
      lastEdited: lastEdited,
      agentIds: agentIds,
      contexts: contexts,
      summaries: summaries,
      status: status,
      userPrompt: json["user_prompt"] as String?,
      submissions: submissions
    );
  }

}
