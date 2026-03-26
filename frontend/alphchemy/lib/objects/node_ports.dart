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
    case "experiment": return Experiment.ports();
    case "backtest_schema": return BacktestSchema.ports();
    case "strategy_gen": return StrategyGen.ports();
    case "strategy": return Strategy.ports();
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
      offset: Offset.zero
    );
    ports.add(port);
  }
  return ports;
}
