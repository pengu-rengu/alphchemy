import "dart:ui";

import "package:alphchemy/objects/experiment.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:uuid/uuid.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

final _uuid = Uuid();

sealed class EditorEvent {
  const EditorEvent();
}

class LoadGraphFromJson extends EditorEvent {
  final Map<String, dynamic> json;

  const LoadGraphFromJson({required this.json});
}

class AddNode extends EditorEvent {
  final String nodeType;

  const AddNode({required this.nodeType});
}

class AddParam extends EditorEvent {
  final Param param;

  const AddParam({required this.param});
}

class UpdateParam extends EditorEvent {
  final String oldName;
  final Param param;

  const UpdateParam({required this.oldName, required this.param});
}

class RemoveParam extends EditorEvent {
  final String name;

  const RemoveParam({required this.name});
}

sealed class EditorState {
  final Map<String, Param> params;

  const EditorState({this.params = const {}});

  Map<String, List<dynamic>> toSearchSpace() {
    final searchSpace = <String, List<dynamic>>{};
    for (final entry in params.entries) {
      searchSpace[entry.key] = entry.value.values;
    }
    return searchSpace;
  }

  List<Param> paramsOfType(ParamType type) {
    final matching = params.values.where((param) => param.type == type);
    return matching.toList();
  }
}

class EditorInitial extends EditorState {
  const EditorInitial({super.params});
}

class EditorLoaded extends EditorState {
  final NodeFlowController<NodeObject, void> controller;

  const EditorLoaded({
    required this.controller,
    super.params
  });
}

class EditorError extends EditorState {
  final String message;

  const EditorError({
    required this.message,
    super.params
  });
}

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc() : super(const EditorInitial()) {
    on<LoadGraphFromJson>(_onLoadGraph);
    on<AddNode>(_onAddNode);
    on<AddParam>(_onAddParam);
    on<UpdateParam>(_onUpdateParam);
    on<RemoveParam>(_onRemoveParam);
  }

  void _onLoadGraph(LoadGraphFromJson event, Emitter<EditorState> emit) {
    final generatorJson = event.json["generator"] as Map<String, dynamic>;
    final graph = ExperimentGenerator.flattenFromJson(generatorJson);
    final controller = NodeFlowController<NodeObject, void>(
      nodes: graph.nodes,
      connections: graph.connections
    );
    final params = _paramsFromJson(event.json["param_space"]);
    _disposeController(state);
    emit(EditorLoaded(controller: controller, params: params));
  }

  void _onAddNode(AddNode event, Emitter<EditorState> emit) {
    final controller = _controllerOrNull();
    if (controller == null) return;

    final factory = ExperimentGenerator.nodeTypeToEmpty[event.nodeType];
    if (factory == null) return;
    
    final data = factory();
    final ports = portsForNodeType(event.nodeType);
    final node = Node<NodeObject>(
      id: _uuid.v4(),
      type: event.nodeType,
      position: controller.getViewportCenter().offset,
      data: data,
      ports: ports,
      size: Size(250, 0)
    );
    controller.addNode(node);
  }

  void _onAddParam(AddParam event, Emitter<EditorState> emit) {
    final params = Map<String, Param>.from(state.params);
    params[event.param.name] = event.param;
    emit(_stateWithParams(params));
  }

  void _onUpdateParam(UpdateParam event, Emitter<EditorState> emit) {
    final oldParam = state.params[event.oldName];
    final oldType = oldParam?.type;
    final newType = event.param.type;
    final typeChanged = oldType != null && oldType != newType;

    if (typeChanged) {
      _clearParamRefs(event.oldName);
    } else if (event.oldName != event.param.name) {
      _rewriteParamRefs(event.oldName, event.param.name);
    }

    final params = _updatedParams(event.oldName, event.param);
    emit(_stateWithParams(params));
  }

  void _onRemoveParam(RemoveParam event, Emitter<EditorState> emit) {
    _clearParamRefs(event.name);
    final params = Map<String, Param>.from(state.params);
    params.remove(event.name);
    emit(_stateWithParams(params));
  }

  NodeFlowController<NodeObject, void>? _controllerOrNull() {
    final current = state;
    if (current is! EditorLoaded) return null;
    return current.controller;
  }

  EditorState _stateWithParams(Map<String, Param> params) {
    final current = state;
    if (current is EditorLoaded) {
      return EditorLoaded(controller: current.controller, params: params);
    }
    if (current is EditorError) {
      return EditorError(message: current.message, params: params);
    }
    return EditorInitial(params: params);
  }

  Map<String, Param> _paramsFromJson(dynamic paramSpaceJson) {
    if (paramSpaceJson is! Map<String, dynamic>) {
      return <String, Param>{};
    }

    final searchSpace = paramSpaceJson["search_space"];
    if (searchSpace is! Map<String, dynamic>) {
      return <String, Param>{};
    }

    final params = <String, Param>{};
    for (final entry in searchSpace.entries) {
      final values = entry.value as List<dynamic>;
      final type = inferParamType(values);
      params[entry.key] = Param(
        name: entry.key,
        type: type,
        values: values
      );
    }
    return params;
  }

  Map<String, Param> _updatedParams(String oldName, Param param) {
    final updated = <String, Param>{};
    var foundOld = false;

    for (final entry in state.params.entries) {
      if (entry.key == oldName) {
        updated[param.name] = param;
        foundOld = true;
        continue;
      }

      if (entry.key == param.name) {
        continue;
      }

      updated[entry.key] = entry.value;
    }

    if (!foundOld) {
      updated[param.name] = param;
    }

    return updated;
  }

  void _clearParamRefs(String paramName) {
    final controller = _controllerOrNull();
    if (controller == null) return;

    for (final node in controller.nodes.values) {
      final fieldKeys = node.data.paramRefs.keys.toList();
      for (final fieldKey in fieldKeys) {
        final refName = node.data.paramRefs[fieldKey];
        if (refName != paramName) continue;
        node.data.paramRefs.remove(fieldKey);
      }
    }
  }

  void _rewriteParamRefs(String oldName, String newName) {
    final controller = _controllerOrNull();
    if (controller == null) return;

    for (final node in controller.nodes.values) {
      final fieldKeys = node.data.paramRefs.keys.toList();
      for (final fieldKey in fieldKeys) {
        final refName = node.data.paramRefs[fieldKey];
        if (refName != oldName) continue;
        node.data.paramRefs[fieldKey] = newName;
      }
    }
  }

  void _disposeController(EditorState current) {
    if (current is! EditorLoaded) return;
    current.controller.dispose();
  }

  Map<String, dynamic> exportToJson() {
    final current = state;
    if (current is! EditorLoaded) {
      throw StateError("Editor must be loaded before export");
    }

    final nodes = current.controller.nodes.values.toList();
    final connections = current.controller.connections.toList();
    final generator = ExperimentGenerator.assembleToJson(nodes, connections);
    return {
      "generator": generator,
      "param_space": {"search_space": current.toSearchSpace()}
    };
  }

  @override
  Future<void> close() {
    _disposeController(state);
    return super.close();
  }
}
