class AgentMessage {
  final String role;
  final String modelOutput;
  final String personalOutput;
  final String globalOutput;

  const AgentMessage({
    required this.role,
    this.modelOutput = "",
    this.personalOutput = "",
    this.globalOutput = ""
  });

  factory AgentMessage.fromJson(Map<String, dynamic> json) {
    final modelOutput = json["model_output"] as String? ?? "";
    final personalOutput = json["personal_output"] as String? ?? "";
    final globalOutput = json["global_output"] as String? ?? "";
    return AgentMessage(
      role: json["role"] as String,
      modelOutput: modelOutput,
      personalOutput: personalOutput,
      globalOutput: globalOutput
    );
  }

  bool get isAssistant {
    return role == "assistant";
  }

  bool get isUserPrompt {
    final trimmed = personalOutput.trimLeft();
    return role == "user" && trimmed.startsWith("[USER]");
  }

  Map<String, dynamic> toJson() {
    if (role == "assistant") {
      return {
        "role": role,
        "model_output": modelOutput
      };
    }
    return {
      "role": role,
      "personal_output": personalOutput,
      "global_output": globalOutput
    };
  }
}

class AgentSubmission {
  final String type;
  final Map<String, dynamic> content;

  const AgentSubmission({required this.type, required this.content});

  factory AgentSubmission.fromJson(Map<String, dynamic> json) {
    final raw = json["submission"];
    final content = _mapFrom(raw);
    final type = json["type"] as String? ?? "unknown";
    return AgentSubmission(type: type, content: content);
  }

  Map<String, dynamic> toJson() {
    return {
      "type": type,
      "submission": content
    };
  }
}

class AgentProposalState {
  final String state;
  final String? type;
  final Map<String, dynamic>? proposal;
  final String? agentId;
  final List<String> votes;
  final AgentSubmission? submission;

  const AgentProposalState({
    required this.state,
    this.type,
    this.proposal,
    this.agentId,
    this.votes = const [],
    this.submission
  });

  factory AgentProposalState.idle() {
    return const AgentProposalState(state: "idle");
  }

  factory AgentProposalState.fromJson(Map<String, dynamic> json) {
    final state = json["state"] as String? ?? "idle";
    final votesRaw = json["votes"] as List<dynamic>? ?? const [];
    final votes = votesRaw.cast<String>();
    final proposal = _nullableMapFrom(json["proposal"]);
    final submission = state == "submission"
        ? AgentSubmission.fromJson(json)
        : null;

    return AgentProposalState(
      state: state,
      type: json["type"] as String?,
      proposal: proposal,
      agentId: json["agent_id"] as String?,
      votes: votes,
      submission: submission
    );
  }

  bool get isSubmission {
    return submission != null;
  }

  Map<String, dynamic> toJson() {
    if (submission != null) {
      return {
        "state": state,
        "type": type,
        "submission": submission!.content
      };
    }

    if (proposal != null) {
      return {
        "state": state,
        "type": type,
        "proposal": proposal,
        "agent_id": agentId,
        "votes": votes
      };
    }

    return {
      "state": state
    };
  }
}

class AgentsState {
  final String userPrompt;
  final Map<String, String> systemPrompts;
  final Map<String, String> summaries;
  final Map<String, List<AgentMessage>> agentContexts;
  final List<String> commands;
  final List<Map<String, dynamic>> params;
  final AgentProposalState proposalState;
  final List<String> agentOrder;
  final int turn;
  final bool isSubagent;

  const AgentsState({
    required this.userPrompt,
    required this.systemPrompts,
    required this.summaries,
    required this.agentContexts,
    required this.commands,
    required this.params,
    required this.proposalState,
    required this.agentOrder,
    required this.turn,
    required this.isSubagent
  });

  factory AgentsState.initial({required List<String> agentIds}) {
    final contexts = <String, List<AgentMessage>>{};
    for (final agentId in agentIds) {
      contexts[agentId] = <AgentMessage>[];
    }
    return AgentsState(
      userPrompt: "",
      systemPrompts: const {},
      summaries: const {},
      agentContexts: contexts,
      commands: const [],
      params: const [],
      proposalState: AgentProposalState.idle(),
      agentOrder: agentIds,
      turn: 0,
      isSubagent: false
    );
  }

  factory AgentsState.fromJson(Map<String, dynamic> json) {
    final userPrompt = json["user_prompt"] as String? ?? "";
    final promptsRaw = json["system_prompts"] as Map<String, dynamic>? ?? const {};
    final summariesRaw = json["summaries"] as Map<String, dynamic>? ?? const {};
    final contextsRaw = json["agent_contexts"] as Map<String, dynamic>? ?? const {};
    final commandsRaw = json["commands"] as List<dynamic>? ?? const [];
    final paramsRaw = json["params"] as List<dynamic>? ?? const [];
    final proposalRaw = json["proposal_state"] as Map<String, dynamic>? ?? const {};
    final orderRaw = json["agent_order"] as List<dynamic>? ?? const [];
    final prompts = _parseStringMap(promptsRaw);
    final summaries = _parseStringMap(summariesRaw);
    final contexts = _parseContexts(contextsRaw);
    final commands = commandsRaw.cast<String>();
    final params = _parseParams(paramsRaw);
    final proposalState = AgentProposalState.fromJson(proposalRaw);
    final agentOrder = _parseAgentOrder(orderRaw, contexts);
    final turn = json["turn"] as int? ?? 0;
    final isSubagent = json["is_subagent"] as bool? ?? false;

    return AgentsState(
      userPrompt: userPrompt,
      systemPrompts: prompts,
      summaries: summaries,
      agentContexts: contexts,
      commands: commands,
      params: params,
      proposalState: proposalState,
      agentOrder: agentOrder,
      turn: turn,
      isSubagent: isSubagent
    );
  }

  AgentSubmission? get finalSubmission {
    return proposalState.submission;
  }

  static Map<String, String> _parseStringMap(Map<String, dynamic> raw) {
    final result = <String, String>{};
    for (final entry in raw.entries) {
      result[entry.key] = entry.value as String? ?? "";
    }
    return result;
  }

  static Map<String, List<AgentMessage>> _parseContexts(Map<String, dynamic> raw) {
    final contexts = <String, List<AgentMessage>>{};
    for (final entry in raw.entries) {
      final list = entry.value as List<dynamic>;
      final mapped = list.map((msg) => AgentMessage.fromJson(msg as Map<String, dynamic>));
      contexts[entry.key] = mapped.toList();
    }
    return contexts;
  }

  static List<Map<String, dynamic>> _parseParams(List<dynamic> raw) {
    final mapped = raw.map((entry) => _mapFrom(entry));
    return mapped.toList();
  }

  static List<String> _parseAgentOrder(
    List<dynamic> raw,
    Map<String, List<AgentMessage>> contexts
  ) {
    if (raw.isNotEmpty) {
      return raw.cast<String>();
    }

    return contexts.keys.toList();
  }

  AgentsState copyWith({
    String? userPrompt,
    Map<String, String>? systemPrompts,
    Map<String, String>? summaries,
    Map<String, List<AgentMessage>>? agentContexts,
    List<String>? commands,
    List<Map<String, dynamic>>? params,
    AgentProposalState? proposalState,
    List<String>? agentOrder,
    int? turn,
    bool? isSubagent
  }) {
    return AgentsState(
      userPrompt: userPrompt ?? this.userPrompt,
      systemPrompts: systemPrompts ?? this.systemPrompts,
      summaries: summaries ?? this.summaries,
      agentContexts: agentContexts ?? this.agentContexts,
      commands: commands ?? this.commands,
      params: params ?? this.params,
      proposalState: proposalState ?? this.proposalState,
      agentOrder: agentOrder ?? this.agentOrder,
      turn: turn ?? this.turn,
      isSubagent: isSubagent ?? this.isSubagent
    );
  }

  Map<String, dynamic> toJson() {
    final paramsJson = _serializeParams(params);
    final contextsJson = _serializeContexts(agentContexts);
    return {
      "user_prompt": userPrompt,
      "system_prompts": systemPrompts,
      "summaries": summaries,
      "agent_contexts": contextsJson,
      "commands": commands,
      "params": paramsJson,
      "proposal_state": proposalState.toJson(),
      "agent_order": agentOrder,
      "turn": turn,
      "is_subagent": isSubagent
    };
  }

  static Map<String, List<Map<String, dynamic>>> _serializeContexts(Map<String, List<AgentMessage>> contexts) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in contexts.entries) {
      final mapped = entry.value.map((msg) => msg.toJson());
      result[entry.key] = mapped.toList();
    }
    return result;
  }

  static List<Map<String, dynamic>> _serializeParams(List<Map<String, dynamic>> params) {
    final mapped = params.map((entry) => Map<String, dynamic>.from(entry));
    return mapped.toList();
  }
}

Map<String, dynamic> _mapFrom(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

Map<String, dynamic>? _nullableMapFrom(dynamic value) {
  if (value == null) {
    return null;
  }

  return _mapFrom(value);
}
