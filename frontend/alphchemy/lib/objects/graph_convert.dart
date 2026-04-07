import "dart:ui";

import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:uuid/uuid.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

const _uuid = Uuid();

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
      type: data.nodeType.value,
      position: Offset.zero,
      data: data,
      ports: ports,
      size: const Size(300, 0),
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
      targetPortId: "in",
    );
    connections.add(conn);
  }
}

class AssembleContext {
  final List<Node<NodeObject>> nodes;
  final List<Connection> connections;

  AssembleContext({required this.nodes, required this.connections});

  Node<NodeObject> findNode(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    throw Exception("Could not find node with id $id");
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
