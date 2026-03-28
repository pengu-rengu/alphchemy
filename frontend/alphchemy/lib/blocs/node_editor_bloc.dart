import "dart:ui";

import "package:alphchemy/blocs/param_space_bloc.dart";
import "package:alphchemy/objects/experiment.dart";
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

class RenameParam extends NodeEditorEvent {
  final String oldName;
  final String newName;

  const RenameParam({required this.oldName, required this.newName});
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
  final ParamSpaceBloc paramSpaceBloc;

  NodeEditorBloc({required this.paramSpaceBloc}) : super(const NodeEditorInitial()) {
    on<LoadGraphFromJson>(_onLoadGraph);
    on<AddNode>(_onAddNode);
    on<RenameParam>(_onRenameParam);
  }

  void _onLoadGraph(LoadGraphFromJson event, Emitter<NodeEditorState> emit) {
    final generatorJson = event.json["generator"] as Map<String, dynamic>;
    final graph = ExperimentGenerator.flattenFromJson(generatorJson);
    final controller = NodeFlowController<NodeObject, void>(
      nodes: graph.nodes,
      connections: graph.connections
    );
    final paramSpaceJson = event.json["param_space"] as Map<String, dynamic>?;
    if (paramSpaceJson != null) {
      final searchSpace = paramSpaceJson["search_space"] as Map<String, dynamic>;
      final casted = searchSpace.map((key, val) {
        return MapEntry(key, (val as List<dynamic>));
      });
      paramSpaceBloc.add(LoadParams(searchSpace: casted));
    }
    emit(NodeEditorLoaded(controller: controller));
  }

  void _onAddNode(AddNode event, Emitter<NodeEditorState> emit) {
    final current = state;
    if (current is! NodeEditorLoaded) return;
    final factory = ExperimentGenerator.nodeTypeToEmpty[event.nodeType];
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

  void _onRenameParam(RenameParam event, Emitter<NodeEditorState> emit) {
    final current = state;
    if (current is! NodeEditorLoaded) return;
    for (final node in current.controller.nodes.values) {
      final refs = node.data.paramRefs;
      for (final key in refs.keys) {
        if (refs[key] == event.oldName) {
          refs[key] = event.newName;
        }
      }
    }
  }

  Map<String, dynamic> exportToJson() {
    final loaded = state as NodeEditorLoaded;
    final nodes = loaded.controller.nodes.values.toList();
    final connections = loaded.controller.connections.toList();
    final generator = ExperimentGenerator.assembleToJson(nodes, connections);
    final searchSpace = paramSpaceBloc.state.toSearchSpace();
    return {
      "generator": generator,
      "param_space": {"search_space": searchSpace}
    };
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
