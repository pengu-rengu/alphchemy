enum AgentStatus {
  created, idle, working, errored;

  const AgentStatus();

  factory AgentStatus.fromJson(dynamic value) {
    final rawStatus = value as String? ?? "created";
    final status = rawStatus.toLowerCase();

    return switch (status) {
      "created" => AgentStatus.created,
      "idle" => AgentStatus.idle,
      "working" => AgentStatus.working,
      "errored" => AgentStatus.errored,
      _ => AgentStatus.created
    };
  }
}


class AgentConfig {
  String id;
  int maxContextLen;
  int nDelete;
  final List<String> chatModels;
  final List<String> summarizeModels;

  AgentConfig({required this.id, required this.maxContextLen, required this.nDelete, required this.chatModels, required this.summarizeModels});

  factory AgentConfig.blank() {
    return AgentConfig(id: "agent", maxContextLen: 0, nDelete: 0, chatModels: [], summarizeModels: []);
  }

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    final chatRaw = json["chat_models"] as List<dynamic>? ?? [];
    final summarizeRaw = json["summarize_models"] as List<dynamic>? ?? [];
    return AgentConfig(
      id: json["id"] as String,
      maxContextLen: json["max_context_len"] as int,
      nDelete: json["n_delete"] as int,
      chatModels: chatRaw.cast<String>(),
      summarizeModels: summarizeRaw.cast<String>()
    );
  }

  AgentConfig copyWith({String? id, int? maxContextLen, int? nDelete, List<String>? chatModels, List<String>? summarizeModels}) {
    return AgentConfig(
      id: id ?? this.id,
      maxContextLen: maxContextLen ?? this.maxContextLen,
      nDelete: nDelete ?? this.nDelete,
      chatModels: chatModels ?? this.chatModels,
      summarizeModels: summarizeModels ?? this.summarizeModels
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "max_context_len": maxContextLen,
      "n_delete": nDelete,
      "chat_models": chatModels,
      "summarize_models": summarizeModels
    };
  }
}

class AgentSystemSchema {
  final List<AgentConfig> agents;
  final List<AgentConfig> subagentPool;

  const AgentSystemSchema({required this.agents, required this.subagentPool});

  factory AgentSystemSchema.blank() {
    return const AgentSystemSchema(agents: [], subagentPool: []);
  }

  factory AgentSystemSchema.fromJson(Map<String, dynamic> json) {
    AgentConfig parseAgent(dynamic json) => AgentConfig.fromJson(json);

    final agents = (json["agents"] as List<dynamic>? ?? []).map(parseAgent).toList();
    final pool = (json["subagent_pool"] as List<dynamic>? ?? []).map(parseAgent).toList();
    return AgentSystemSchema(agents: agents, subagentPool: pool);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> agentToJson(AgentConfig agent) => agent.toJson();

    final agentsJson = agents.map(agentToJson).toList();
    final subagentsJson = subagentPool.map(agentToJson).toList();
    return {
      "agents": agentsJson,
      "subagent_pool": subagentsJson
    };
  }

  AgentSystemSchema copy() {
    return AgentSystemSchema.fromJson(toJson());
  }
}
