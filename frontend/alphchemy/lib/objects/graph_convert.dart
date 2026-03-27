import "dart:ui";

import "package:alphchemy/objects/actions.dart";
import "package:alphchemy/objects/experiment.dart";
import "package:alphchemy/objects/features.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/objects/optimizer.dart";
import "package:uuid/uuid.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

final nodeTypeToEmpty = <String, NodeObject Function()>{
  "experiment_gen": ExperimentGenerator.new,
  "backtest_schema": BacktestSchema.new,
  "strategy_gen": StrategyGen.new,
  "network_gen": NetworkGen.new,
  "logic_net": LogicNet.new,
  "decision_net": DecisionNet.new,
  "input_node": InputNode.new,
  "gate_node": GateNode.new,
  "branch_node": BranchNode.new,
  "ref_node": RefNode.new,
  "node_ptr": NodePtr.new,
  "constant_feature": ConstantFeature.new,
  "raw_returns_feature": RawReturnsFeature.new,
  "actions_gen": ActionsGen.new,
  "logic_actions": LogicActions.new,
  "decision_actions": DecisionActions.new,
  "meta_action": MetaAction.new,
  "threshold_range": ThresholdRange.new,
  "penalties_gen": PenaltiesGen.new,
  "logic_penalties": LogicPenalties.new,
  "decision_penalties": DecisionPenalties.new,
  "stop_conds": StopConds.new,
  "genetic_opt": GeneticOpt.new,
  "entry_schema": EntrySchema.new,
  "exit_schema": ExitSchema.new
};

final _uuid = Uuid();

class GraphData {
  final List<Node<NodeObject>> nodes;
  final List<Connection> connections;

  GraphData({required this.nodes, required this.connections});
}

class FlattenContext {
  final nodes = <Node<NodeObject>>[];
  final connections = <Connection>[];

  String addNode(NodeObject data) {
    final nodeId = _uuid.v4();
    final ports = portsForNodeType(data.nodeType);
    final node = Node<NodeObject>(
      id: nodeId,
      type: data.nodeType,
      position: Offset.zero,
      data: data,
      ports: ports,
      size: Size(300, 0)
    );
    nodes.add(node);
    return nodeId;
  }

  void connect(String sourceId, String sourcePort, String targetId) {
    final connId = _uuid.v4();
    final conn = Connection(
      id: connId,
      sourceNodeId: sourceId,
      sourcePortId: sourcePort,
      targetNodeId: targetId,
      targetPortId: "in"
    );
    connections.add(conn);
  }
}

class AssembleContext {
  final List<Node<NodeObject>> nodes;
  final List<Connection> connections;

  AssembleContext({required this.nodes, required this.connections});

  Node<NodeObject>? findNode(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  List<String> childIds(String parentId, String sourcePort) {
    final ids = <String>[];
    for (final conn in connections) {
      final matchesParent = conn.sourceNodeId == parentId;
      final matchesPort = conn.sourcePortId == sourcePort;
      if (matchesParent && matchesPort) {
        ids.add(conn.targetNodeId);
      }
    }
    return ids;
  }

  String? childId(String parentId, String sourcePort) {
    final ids = childIds(parentId, sourcePort);
    if (ids.isEmpty) return null;
    return ids.first;
  }
}

int? indexOf(List<String> ids, String? targetId) {
  if (targetId == null) return null;
  final idx = ids.indexOf(targetId);
  if (idx < 0) return null;
  return idx;
}

GraphData flattenExperimentGen(Map<String, dynamic> json) {
  final ctx = FlattenContext();
  final refs = <String, String>{};

  final title = stringOrDefault(json, "title", "title", "", refs);
  final valSize = doubleOrDefault(json, "val_size", "valSize", 0.2, refs);
  final testSize = doubleOrDefault(json, "test_size", "testSize", 0.1, refs);
  final cvFolds = intOrDefault(json, "cv_folds", "cvFolds", 3, refs);
  final foldSize = doubleOrDefault(json, "fold_size", "foldSize", 0.3, refs);

  String backtestSchemaId = "";
  final backtestJson = json["backtest_schema"] as Map<String, dynamic>?;
  if (backtestJson != null) {
    backtestSchemaId = BacktestSchema.flatten(ctx, backtestJson);
  }

  String strategyId = "";
  final strategyJson = json["strategy"] as Map<String, dynamic>?;
  if (strategyJson != null) {
    strategyId = StrategyGen.flatten(ctx, strategyJson);
  } else {
    strategyId = ctx.addNode(StrategyGen());
  }

  final rootData = ExperimentGenerator(
    title: title,
    valSize: valSize,
    testSize: testSize,
    cvFolds: cvFolds,
    foldSize: foldSize,
    backtestSchemaId: backtestSchemaId,
    strategyId: strategyId
  );
  rootData.paramRefs.addAll(refs);
  final rootId = ctx.addNode(rootData);
  if (backtestSchemaId.isNotEmpty) {
    ctx.connect(rootId, "out_backtest_schema", backtestSchemaId);
  }
  ctx.connect(rootId, "out_strategy", strategyId);

  return GraphData(nodes: ctx.nodes, connections: ctx.connections);
}

Map<String, dynamic> assembleExperimentGen(List<Node<NodeObject>> nodes, List<Connection> connections) {
  final ctx = AssembleContext(nodes: nodes, connections: connections);

  Node<NodeObject>? rootNode;
  for (final node in nodes) {
    if (node.data.nodeType == "experiment_gen") {
      rootNode = node;
      break;
    }
  }

  final rootData = rootNode!.data as ExperimentGenerator;
  final strategyNodeId = ctx.childId(rootNode.id, "out_strategy")!;
  final backtestNodeId = ctx.childId(rootNode.id, "out_backtest_schema");

  final result = <String, dynamic>{
    "title": assembleField(rootData.title, "title", rootData.paramRefs),
    "val_size": assembleField(rootData.valSize, "valSize", rootData.paramRefs),
    "test_size": assembleField(rootData.testSize, "testSize", rootData.paramRefs),
    "cv_folds": assembleField(rootData.cvFolds, "cvFolds", rootData.paramRefs),
    "fold_size": assembleField(rootData.foldSize, "foldSize", rootData.paramRefs),
    "strategy": StrategyGen.assemble(ctx, strategyNodeId)
  };
  if (backtestNodeId != null) {
    result["backtest_schema"] = BacktestSchema.assemble(ctx, backtestNodeId);
  }
  return result;
}
