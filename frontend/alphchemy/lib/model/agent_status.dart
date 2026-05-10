enum AgentStatus {
  created("created"),
  idle("idle"),
  working("working");

  final String label;

  const AgentStatus(this.label);

  factory AgentStatus.fromJson(dynamic value) {
    final rawStatus = value as String? ?? "created";
    final status = rawStatus.toLowerCase();

    return switch (status) {
      "created" => AgentStatus.created,
      "idle" => AgentStatus.idle,
      "working" => AgentStatus.working,
      _ => AgentStatus.created
    };
  }

  bool get canReceivePrompt {
    return this == AgentStatus.idle;
  }
}
