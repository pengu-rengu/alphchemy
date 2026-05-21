enum AgentStatus {
  created, idle, working, errored;

  const AgentStatus();

  factory AgentStatus.fromJson(dynamic value) {
    return switch (value as String) {
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
  String chatModel;
  String chatFallbackModel;
  String summarizeModel;
  String summarizeFallbackModel;
  String additionalInstructions;

  AgentConfig({required this.id, required this.maxContextLen, required this.nDelete, required this.chatModel, required this.chatFallbackModel, required this.summarizeModel, required this.summarizeFallbackModel, required this.additionalInstructions});

  factory AgentConfig.blank() {
    return AgentConfig(
      id: "agent",
      maxContextLen: 0,
      nDelete: 0,
      chatModel: "",
      chatFallbackModel: "",
      summarizeModel: "",
      summarizeFallbackModel: "",
      additionalInstructions: ""
    );
  }

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    final maxContextLen = json["max_context_len"] as int;
    final nDelete = json["n_delete"] as int;
    final chatModel = json["chat_model"] as String;
    final chatFallbackModel = json["chat_fallback_model"] as String;
    final summarizeModel = json["summarize_model"] as String;
    final summarizeFallbackModel = json["summarize_fallback_model"] as String;
    final additionalInstructions = json["additional_instructions"] as String;

    return AgentConfig(
      id: json["id"] as String,
      maxContextLen:  maxContextLen,
      nDelete: nDelete,
      chatModel: chatModel,
      chatFallbackModel: chatFallbackModel,
      summarizeModel: summarizeModel,
      summarizeFallbackModel: summarizeFallbackModel,
      additionalInstructions: additionalInstructions
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "max_context_len": maxContextLen,
      "n_delete": nDelete,
      "chat_model": chatModel,
      "chat_fallback_model": chatFallbackModel,
      "summarize_model": summarizeModel,
      "summarize_fallback_model": summarizeFallbackModel,
      "additional_instructions": additionalInstructions
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
