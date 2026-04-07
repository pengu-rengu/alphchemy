import "dart:ui";

import "package:alphchemy/model/generator/actions.dart";
import "package:alphchemy/model/generator/experiment.dart";
import "package:alphchemy/model/generator/features.dart";
import "package:alphchemy/model/generator/network.dart";
import "package:alphchemy/model/generator/node_object.dart";
import "package:alphchemy/model/generator/optimizer.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

List<Port> portsForNodeType(NodeType nodeType) {
  switch (nodeType) {
    case NodeType.experimentGen: return ExperimentGenerator.ports();
    case NodeType.backtestSchema: return BacktestSchema.ports();
    case NodeType.strategyGen: return Strategy.ports();
    case NodeType.networkGen: return Network.ports();
    case NodeType.actionsGen: return Actions.ports();
    case NodeType.penaltiesGen: return Penalties.ports();
    case NodeType.logicNet: return LogicNet.ports();
    case NodeType.decisionNet: return DecisionNet.ports();
    case NodeType.inputNode: return InputNode.ports();
    case NodeType.gateNode: return GateNode.ports();
    case NodeType.branchNode: return BranchNode.ports();
    case NodeType.refNode: return RefNode.ports();
    case NodeType.nodePtr: return NodePtr.ports();
    case NodeType.logicPenalties: return LogicPenalties.ports();
    case NodeType.decisionPenalties: return DecisionPenalties.ports();
    case NodeType.logicActions: return LogicActions.ports();
    case NodeType.decisionActions: return DecisionActions.ports();
    case NodeType.stopConds: return StopConds.ports();
    case NodeType.geneticOpt: return GeneticOpt.ports();
    case NodeType.constantFeature: return Constant.ports();
    case NodeType.rawReturnsFeature: return RawReturns.ports();
    case NodeType.thresholdRange: return ThresholdRange.ports();
    case NodeType.metaAction: return MetaAction.ports();
    case NodeType.entrySchema: return EntrySchema.ports();
    case NodeType.exitSchema: return ExitSchema.ports();
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

const allowedChildren = <NodeType, Map<String, Set<NodeType>>>{
  NodeType.experimentGen: {
    "backtest_schema": {NodeType.backtestSchema},
    "strategy": {NodeType.strategyGen}
  },
  NodeType.strategyGen: {
    "base_net": {NodeType.networkGen},
    "feat_pool": {NodeType.constantFeature, NodeType.rawReturnsFeature},
    "actions": {NodeType.actionsGen},
    "penalties": {NodeType.penaltiesGen},
    "stop_conds": {NodeType.stopConds},
    "opt": {NodeType.geneticOpt},
    "entry_pool": {NodeType.entrySchema},
    "exit_pool": {NodeType.exitSchema}
  },
  NodeType.networkGen: {
    "logic_net": {NodeType.logicNet},
    "decision_net": {NodeType.decisionNet}
  },
  NodeType.logicNet: {
    "nodes": {NodeType.inputNode, NodeType.gateNode}
  },
  NodeType.decisionNet: {
    "nodes": {NodeType.branchNode, NodeType.refNode}
  },
  NodeType.actionsGen: {
    "logic_actions": {NodeType.logicActions},
    "decision_actions": {NodeType.decisionActions}
  },
  NodeType.logicActions: {
    "meta_actions": {NodeType.metaAction},
    "thresholds": {NodeType.thresholdRange}
  },
  NodeType.decisionActions: {
    "meta_actions": {NodeType.metaAction},
    "thresholds": {NodeType.thresholdRange}
  },
  NodeType.penaltiesGen: {
    "logic_penalties": {NodeType.logicPenalties},
    "decision_penalties": {NodeType.decisionPenalties}
  },
  NodeType.entrySchema: {
    "node_ptr": {NodeType.nodePtr}
  },
  NodeType.exitSchema: {
    "node_ptr": {NodeType.nodePtr}
  }
};

bool canConnect(NodeType sourceType, String portId, NodeType targetType) {
  final portMap = allowedChildren[sourceType];
  if (portMap == null) return false;
  final allowed = portMap[portId];
  if (allowed == null) return false;
  return allowed.contains(targetType);
}

List<Port> outputPorts(List<String> names, {bool multiConnections = true}) {
  final ports = <Port>[];
  for (var i = 0; i < names.length; i++) {
    final port = Port(
      id: names[i],
      name: names[i],
      position: PortPosition.right,
      type: PortType.output,
      showLabel: true,
      multiConnections: multiConnections,
    );
    ports.add(port);
  }
  return ports;
}
