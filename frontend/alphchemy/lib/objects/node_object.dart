enum NodeType {
  constantFeature,
  rawReturnsFeature,
  experimentGen,
  backtestSchema,
  strategyGen,
  networkGen,
  logicNet,
  decisionNet,
  inputNode,
  gateNode,
  branchNode,
  refNode,
  nodePtr,
  
  actionsGen,
  logicActions,
  decisionActions,
  metaAction,
  thresholdRange,
  penaltiesGen,
  logicPenalties,
  decisionPenalties,
  stopConds,
  geneticOpt,
  entrySchema,
  exitSchema;

  String get value {
    return switch (this) {
      NodeType.constantFeature => "constant_feature",
      NodeType.rawReturnsFeature => "raw_returns_feature",
      NodeType.experimentGen => "experiment_gen",
      NodeType.backtestSchema => "backtest_schema",
      NodeType.strategyGen => "strategy_gen",
      NodeType.networkGen => "network_gen",
      NodeType.logicNet => "logic_net",
      NodeType.decisionNet => "decision_net",
      NodeType.inputNode => "input_node",
      NodeType.gateNode => "gate_node",
      NodeType.branchNode => "branch_node",
      NodeType.refNode => "ref_node",
      NodeType.nodePtr => "node_ptr",
      NodeType.actionsGen => "actions_gen",
      NodeType.logicActions => "logic_actions",
      NodeType.decisionActions => "decision_actions",
      NodeType.metaAction => "meta_action",
      NodeType.thresholdRange => "threshold_range",
      NodeType.penaltiesGen => "penalties_gen",
      NodeType.logicPenalties => "logic_penalties",
      NodeType.decisionPenalties => "decision_penalties",
      NodeType.stopConds => "stop_conds",
      NodeType.geneticOpt => "genetic_opt",
      NodeType.entrySchema => "entry_schema",
      NodeType.exitSchema => "exit_schema"
    };
  }
}

abstract class NodeObject {
  NodeType get nodeType;
  Map<String, String> paramRefs = {};

  NodeObject({Map<String, String>? paramRefs}) {
    if (paramRefs != null) {
      this.paramRefs = paramRefs;
    }
  }

  void updateField(String field, String text);
  void updateFieldTyped(String field, dynamic value);
  String formatField(String field);

  List<String> parseList(String text) {
    final result = <String>[];
    
    for (final part in text.split(",")) {
      final trimmed = part.trim();

      if (trimmed.isNotEmpty) {
        result.add(trimmed);
      }
    }
    return result;
  }
}
