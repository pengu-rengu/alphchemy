import "dart:ui";

import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:uuid/uuid.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

final _uuid = Uuid();

sealed class NodeEditorEvent {
  const NodeEditorEvent();
}

class LoadGraphFromJson extends NodeEditorEvent {
  final Map<String, dynamic> json;

  const LoadGraphFromJson({required this.json});
}

class AddNode extends NodeEditorEvent {
  final String nodeType;

  const AddNode({required this.nodeType});
}

sealed class NodeEditorState {
  const NodeEditorState();
}

class NodeEditorInitial extends NodeEditorState {
  const NodeEditorInitial();
}

class NodeEditorLoaded extends NodeEditorState {
  final NodeFlowController<NodeObject, void> controller;

  const NodeEditorLoaded({required this.controller});
}

class NodeEditorError extends NodeEditorState {
  final String message;

  const NodeEditorError({required this.message});
}

class NodeEditorBloc extends Bloc<NodeEditorEvent, NodeEditorState> {
  NodeEditorBloc() : super(const NodeEditorInitial()) {
    on<LoadGraphFromJson>(_onLoadGraph);
    on<AddNode>(_onAddNode);
  }

  void _onLoadGraph(LoadGraphFromJson event, Emitter<NodeEditorState> emit) {
    final graph = flattenExperimentGen(event.json);
    final controller = NodeFlowController<NodeObject, void>(
      nodes: graph.nodes,
      connections: graph.connections
    );
    final newState = NodeEditorLoaded(controller: controller);
    emit(newState);
  }

  void _onAddNode(AddNode event, Emitter<NodeEditorState> emit) {
    final current = state;
    if (current is! NodeEditorLoaded) return;
    final factory = nodeTypeToEmpty[event.nodeType];
    if (factory == null) return;
    final data = factory();
    final ports = portsForNodeType(event.nodeType);
    final node = Node<NodeObject>(
      id: _uuid.v4(),
      type: event.nodeType,
      position: Offset.zero,
      data: data,
      ports: ports,
      size: Size(250, 0)
    );
    current.controller.addNode(node);
  }

  Map<String, dynamic> exportToJson() {
    final loaded = state as NodeEditorLoaded;
    final nodes = loaded.controller.nodes.values.toList();
    final connections = loaded.controller.connections.toList();
    return assembleExperimentGen(nodes, connections);
  }

  @override
  Future<void> close() {
    final current = state;
    if (current is NodeEditorLoaded) {
      current.controller.dispose();
    }
    return super.close();
  }
}
