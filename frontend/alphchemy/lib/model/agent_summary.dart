import "package:alphchemy/model/agent_status.dart";

class AgentSummary {
  final int id;
  final String title;
  final DateTime lastEdited;
  final AgentStatus status;
  final bool hasPendingPrompt;

  const AgentSummary({
    required this.id,
    required this.title,
    required this.lastEdited,
    required this.status,
    required this.hasPendingPrompt
  });
}
