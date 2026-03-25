import 'package:alphchemy/model/graph_convert.dart';
import 'package:alphchemy/model/node_object.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

sealed class NodeEditorEvent {
  const NodeEditorEvent();
}

class LoadGraphFromJson extends NodeEditorEvent {
  final Map<String, dynamic> json;

  const LoadGraphFromJson({required this.json});
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
  }

  void _onLoadGraph(LoadGraphFromJson event, Emitter<NodeEditorState> emit) {
    final graph = flattenExperimentGen(event.json);
    final controller = NodeFlowController<NodeObject, void>(
      nodes: graph.nodes,
      connections: graph.connections
    );
    emit(NodeEditorLoaded(controller: controller));
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
