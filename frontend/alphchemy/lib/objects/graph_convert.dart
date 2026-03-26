import "dart:math";
import "dart:ui";

import "package:alphchemy/objects/experiment.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:uuid/uuid.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

final _uuid = Uuid();

class GraphData {
  final List<Node<NodeObject>> nodes;
  final List<Connection> connections;

  GraphData({required this.nodes, required this.connections});
}

class FlattenContext {
  final nodes = <Node<NodeObject>>[];
  final connections = <Connection>[];
  final _yPerCol = <int, double>{};

  String addNode(NodeObject data, int column) {
    final nodeId = _uuid.v4();
    final ports = portsForNodeType(data.nodeType);
    final outputCount = ports.where((port) {
      return port.type == PortType.output;
    }).length;
    final height = max(150.0, outputCount * 25.0 + 80);

    final yPos = _yPerCol[column] ?? 0.0;
    _yPerCol[column] = yPos + height + 20;
    final position = Offset(column * 250.0, yPos);
    final node = Node<NodeObject>(
      id: nodeId,
      type: data.nodeType,
      position: position,
      data: data,
      ports: ports,
      size: Size(250, height)
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

  final title = json["title"] as String;
  final valSize = doubleFromJson(json["val_size"]);
  final testSize = doubleFromJson(json["test_size"]);
  final cvFolds = json["cv_folds"] as int;
  final foldSize = doubleFromJson(json["fold_size"]);

  final backtestJson = json["backtest_schema"] as Map<String, dynamic>;
  final backtestSchemaId = BacktestSchema.flatten(ctx, backtestJson, 1);

  final strategyJson = json["strategy"] as Map<String, dynamic>;
  final strategyId = StrategyGen.flatten(ctx, strategyJson, 1);

  final rootData = ExperimentGenerator(
    title: title,
    valSize: valSize,
    testSize: testSize,
    cvFolds: cvFolds,
    foldSize: foldSize,
    backtestSchemaId: backtestSchemaId,
    strategyId: strategyId
  );
  final rootId = ctx.addNode(rootData, 0);
  ctx.connect(rootId, "out_backtest_schema", backtestSchemaId);
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
  final backtestNodeId = ctx.childId(rootNode.id, "out_backtest_schema")!;

  return {
    "title": rootData.title,
    "val_size": rootData.valSize,
    "test_size": rootData.testSize,
    "cv_folds": rootData.cvFolds,
    "fold_size": rootData.foldSize,
    "backtest_schema": BacktestSchema.assemble(ctx, backtestNodeId),
    "strategy": StrategyGen.assemble(ctx, strategyNodeId)
  };
}
