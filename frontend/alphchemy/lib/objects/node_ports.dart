import "dart:ui";

import "package:alphchemy/objects/actions.dart";
import "package:alphchemy/objects/experiment.dart";
import "package:alphchemy/objects/features.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/optimizer.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

List<Port> portsForNodeType(String nodeType) {
  switch (nodeType) {
    case "experiment_gen": return ExperimentGenerator.ports();
    case "backtest_schema": return BacktestSchema.ports();
    case "strategy_gen": return StrategyGen.ports();
    case "network_gen": return NetworkGen.ports();
    case "actions_gen": return ActionsGen.ports();
    case "penalties_gen": return PenaltiesGen.ports();
    case "logic_net": return LogicNet.ports();
    case "decision_net": return DecisionNet.ports();
    case "input_node": return InputNode.ports();
    case "gate_node": return GateNode.ports();
    case "branch_node": return BranchNode.ports();
    case "ref_node": return RefNode.ports();
    case "node_ptr": return NodePtr.ports();
    case "logic_penalties": return LogicPenalties.ports();
    case "decision_penalties": return DecisionPenalties.ports();
    case "logic_actions": return LogicActions.ports();
    case "decision_actions": return DecisionActions.ports();
    case "stop_conds": return StopConds.ports();
    case "genetic_opt": return GeneticOpt.ports();
    case "constant_feature": return ConstantFeature.ports();
    case "raw_returns_feature": return RawReturnsFeature.ports();
    case "threshold_range": return ThresholdRange.ports();
    case "meta_action": return MetaAction.ports();
    case "entry_schema": return EntrySchema.ports();
    case "exit_schema": return ExitSchema.ports();
    default: return inputPort();
  }
}

List<Port> inputPort() {
  return [
    Port(
      id: "in",
      name: "In",
      position: PortPosition.left,
      type: PortType.input,
      multiConnections: true,
      offset: Offset.zero
    )
  ];
}

const allowedChildren = <String, Map<String, Set<String>>>{
  "experiment_gen": {
    "out_backtest_schema": {"backtest_schema"},
    "out_strategy": {"strategy_gen"}
  },
  "strategy_gen": {
    "out_base_net": {"network_gen"},
    "out_feat_pool": {"constant_feature", "raw_returns_feature"},
    "out_actions": {"actions_gen"},
    "out_penalties": {"penalties_gen"},
    "out_stop_conds": {"stop_conds"},
    "out_opt": {"genetic_opt"},
    "out_entry_pool": {"entry_schema"},
    "out_exit_pool": {"exit_schema"}
  },
  "network_gen": {
    "out_logic_net": {"logic_net"},
    "out_decision_net": {"decision_net"}
  },
  "logic_net": {
    "out_nodes": {"input_node", "gate_node"}
  },
  "decision_net": {
    "out_nodes": {"branch_node", "ref_node"}
  },
  "actions_gen": {
    "out_logic_actions": {"logic_actions"},
    "out_decision_actions": {"decision_actions"}
  },
  "logic_actions": {
    "out_meta_actions": {"meta_action"},
    "out_thresholds": {"threshold_range"}
  },
  "decision_actions": {
    "out_meta_actions": {"meta_action"},
    "out_thresholds": {"threshold_range"}
  },
  "penalties_gen": {
    "out_logic_penalties": {"logic_penalties"},
    "out_decision_penalties": {"decision_penalties"}
  },
  "entry_schema": {
    "out_node_ptr": {"node_ptr"}
  },
  "exit_schema": {
    "out_node_ptr": {"node_ptr"}
  }
};

bool canConnect(String sourceType, String portId, String targetType) {
  final portMap = allowedChildren[sourceType];
  if (portMap == null) return false;
  final allowed = portMap[portId];
  if (allowed == null) return false;
  return allowed.contains(targetType);
}

List<Port> outputPorts(List<String> names) {
  final ports = <Port>[];
  for (var i = 0; i < names.length; i++) {
    final port = Port(
      id: "out_${names[i]}",
      name: names[i],
      position: PortPosition.right,
      type: PortType.output,
      showLabel: true,
      multiConnections: true,
    );
    ports.add(port);
  }
  return ports;
}
