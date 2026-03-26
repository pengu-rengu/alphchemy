import "dart:math";
import "dart:ui";

import "package:alphchemy/objects/actions.dart";
import "package:alphchemy/objects/experiment.dart";
import "package:alphchemy/objects/features.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/optimizer.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

int fieldCountForType(String nodeType) {
  switch (nodeType) {
    case "experiment_gen": return ExperimentGenerator.fieldCount;
    case "experiment": return Experiment.fieldCount;
    case "backtest_schema": return BacktestSchema.fieldCount;
    case "strategy_gen": return StrategyGen.fieldCount;
    case "strategy": return Strategy.fieldCount;
    case "network_gen": return NetworkGen.fieldCount;
    case "actions_gen": return ActionsGen.fieldCount;
    case "penalties_gen": return PenaltiesGen.fieldCount;
    case "logic_net": return LogicNet.fieldCount;
    case "decision_net": return DecisionNet.fieldCount;
    case "input_node": return InputNode.fieldCount;
    case "gate_node": return GateNode.fieldCount;
    case "branch_node": return BranchNode.fieldCount;
    case "ref_node": return RefNode.fieldCount;
    case "node_ptr": return NodePtr.fieldCount;
    case "logic_penalties": return LogicPenalties.fieldCount;
    case "decision_penalties": return DecisionPenalties.fieldCount;
    case "logic_actions": return LogicActions.fieldCount;
    case "decision_actions": return DecisionActions.fieldCount;
    case "stop_conds": return StopConds.fieldCount;
    case "genetic_opt": return GeneticOpt.fieldCount;
    case "constant_feature": return ConstantFeature.fieldCount;
    case "raw_returns_feature": return RawReturnsFeature.fieldCount;
    case "threshold_range": return ThresholdRange.fieldCount;
    case "meta_action": return MetaAction.fieldCount;
    case "entry_schema": return EntrySchema.fieldCount;
    case "exit_schema": return ExitSchema.fieldCount;
    default: return 0;
  }
}

double contentHeight(int fieldCount) {
  return 28.0 + fieldCount * 26.0;
}

double portTopOffset(int fieldCount) {
  final contentBottom = contentHeight(fieldCount) + 4.0;
  return max(30.0, contentBottom);
}

double nodeHeight(int outputCount, int fieldCount) {
  final topOffset = portTopOffset(fieldCount);
  if (outputCount <= 0) {
    return max(60.0, contentHeight(fieldCount) + 16.0);
  }
  final lastPortY = topOffset + (outputCount - 1) * 25.0;
  return lastPortY + 25.0;
}

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
    default: return inputPort(0, 0);
  }
}

List<Port> inputPort(int outputCount, int fieldCount) {
  final height = nodeHeight(outputCount, fieldCount);
  return [
    Port(
      id: "in",
      name: "In",
      position: PortPosition.left,
      type: PortType.input,
      multiConnections: true,
      offset: Offset(0, height / 2)
    )
  ];
}

List<Port> outputPorts(List<String> names, double topOffset) {
  final ports = <Port>[];
  for (var i = 0; i < names.length; i++) {
    final portName = names[i];
    final port = Port(
      id: "out_$portName",
      name: portName,
      position: PortPosition.right,
      type: PortType.output,
      showLabel: true,
      multiConnections: true,
      offset: Offset(0, topOffset + i * 25.0)
    );
    ports.add(port);
  }
  return ports;
}
