class AgentConfig {
  final String id;
  final int maxContextLen;
  final int nDelete;
  final List<String> chatModels;
  final List<String> summarizeModels;

  const AgentConfig({
    required this.id,
    required this.maxContextLen,
    required this.nDelete,
    required this.chatModels,
    required this.summarizeModels
  });

  factory AgentConfig.blank() {
    return const AgentConfig(
      id: "agent",
      maxContextLen: 15,
      nDelete: 5,
      chatModels: ["deepseek/deepseek-v3.2"],
      summarizeModels: ["deepseek/deepseek-v3.2"]
    );
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

  AgentConfig copyWith({
    String? id,
    int? maxContextLen,
    int? nDelete,
    List<String>? chatModels,
    List<String>? summarizeModels
  }) {
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
    final blank = AgentConfig.blank();
    return AgentSystemSchema(agents: [blank], subagentPool: const []);
  }

  factory AgentSystemSchema.fromJson(Map<String, dynamic> json) {
    final agentsRaw = json["agents"] as List<dynamic>? ?? [];
    final poolRaw = json["subagent_pool"] as List<dynamic>? ?? [];
    final agents = _parseAgents(agentsRaw);
    final pool = _parseAgents(poolRaw);
    return AgentSystemSchema(agents: agents, subagentPool: pool);
  }

  static List<AgentConfig> _parseAgents(List<dynamic> raw) {
    final mapped = raw.map((entry) => AgentConfig.fromJson(entry as Map<String, dynamic>));
    return mapped.toList();
  }

  Map<String, dynamic> toJson() {
    final agentsJson = _serializeAgents(agents);
    final poolJson = _serializeAgents(subagentPool);
    return {
      "agents": agentsJson,
      "subagent_pool": poolJson
    };
  }

  static List<Map<String, dynamic>> _serializeAgents(List<AgentConfig> list) {
    final mapped = list.map((agent) => agent.toJson());
    return mapped.toList();
  }
}
