import "dart:ui";

import "package:alphchemy/model/generator/experiment.dart";
import "package:alphchemy/model/generator/node_object.dart";
import "package:alphchemy/model/generator/node_ports.dart";
import "package:alphchemy/model/generator/param_space.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:uuid/uuid.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

const _uuid = Uuid();

sealed class EditorEvent {
  const EditorEvent();
}

class LoadGraphFromJson extends EditorEvent {
  final Map<String, dynamic> json;

  const LoadGraphFromJson({required this.json});
}

class AddNode extends EditorEvent {
  final NodeType nodeType;

  const AddNode({required this.nodeType});
}

class AddParam extends EditorEvent {
  final String name;
  final Param param;

  const AddParam({required this.name, required this.param});
}

class UpdateParamValues extends EditorEvent {
  final String name;
  final String text;

  const UpdateParamValues({required this.name, required this.text});
}

class UpdateParamType extends EditorEvent {
  final String name;
  final ParamType type;

  const UpdateParamType({required this.name, required this.type});
}

class RenameParam extends EditorEvent {
  final String oldName;
  final String newName;

  const RenameParam({required this.oldName, required this.newName});
}

class RemoveParam extends EditorEvent {
  final String name;

  const RemoveParam({required this.name});
}

sealed class EditorState {
  const EditorState();
}

class EditorInitial extends EditorState {
  const EditorInitial();
}

class EditorLoaded extends EditorState {
  final NodeFlowController<NodeObject, void> controller;
  final ParamSpace paramSpace;

  const EditorLoaded({required this.controller, required this.paramSpace});
}

class EditorError extends EditorState {
  final String message;

  const EditorError({required this.message});
}

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc() : super(const EditorInitial()) {
    on<LoadGraphFromJson>(_onLoadGraph);
    on<AddNode>(_onAddNode);
    on<AddParam>(_onAddParam);
    on<UpdateParamValues>(_onUpdateParamValues);
    on<UpdateParamType>(_onUpdateParamType);
    on<RenameParam>(_onRenameParam);
    on<RemoveParam>(_onRemoveParam);
  }

  void _onLoadGraph(LoadGraphFromJson event, Emitter<EditorState> emit) {
    final flattenCtx = ExperimentGenerator.flatten(event.json["generator"] as Map<String, dynamic>);
    final controller = NodeFlowController<NodeObject, void>(
      nodes: flattenCtx.nodes,
      connections: flattenCtx.connections,
    );
    final paramSpace = ParamSpace.fromJson(event.json["param_space"] as Map<String, dynamic>);

    _disposeController();

    final newState = EditorLoaded(controller: controller, paramSpace: paramSpace);
    emit(newState);
  }

  void _onAddNode(AddNode event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) {
      return;
    }
    final controller = (state as EditorLoaded).controller;

    final factory = ExperimentGenerator.nodeTypeToEmpty[event.nodeType];
    if (factory == null) return;

    final data = factory();
    final ports = portsForNodeType(event.nodeType);
    final node = Node<NodeObject>(
      id: _uuid.v4(),
      type: event.nodeType.value,
      position: controller.getViewportCenter().offset,
      data: data,
      ports: ports,
      size: const Size(250, 0),
    );
    controller.addNode(node);
  }

  void _onAddParam(AddParam event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) {
      return;
    }

    final paramSpace = (state as EditorLoaded).paramSpace.copy();
    paramSpace.addParam(event.name, event.param);
    
    _emitParamSpace(emit, paramSpace);
  }

  void _onUpdateParamValues(UpdateParamValues event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) {
      return;
    }

    final paramSpace = (state as EditorLoaded).paramSpace.copy();
    paramSpace.updateParamValues(event.name, event.text);

    _emitParamSpace(emit, paramSpace);
  }

  void _onUpdateParamType(UpdateParamType event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) {
      return;
    }

    final name = event.name;
    final paramSpace = (state as EditorLoaded).paramSpace.copy();
    paramSpace.updateParamType(name, event.type);

    _clearParamRefs(name);
    _emitParamSpace(emit, paramSpace);
  }
  
  void _onRenameParam(RenameParam event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) {
      return;
    }

    final paramSpace = (state as EditorLoaded).paramSpace.copy();
    paramSpace.renameParam(event.oldName, event.newName);

    _renameParamRefs(event.oldName, event.newName);
    _emitParamSpace(emit, paramSpace);
  }

  void _onRemoveParam(RemoveParam event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) {
      return;
    }

    final name = event.name;
    final paramSpace = (state as EditorLoaded).paramSpace.copy();
    paramSpace.removeParam(name);

    _clearParamRefs(name);
    _emitParamSpace(emit, paramSpace);
  }

  void _emitParamSpace(Emitter<EditorState> emit, ParamSpace paramSpace) {
    final newState = EditorLoaded(controller: (state as EditorLoaded).controller, paramSpace: paramSpace);
    emit(newState);
  }

  void _clearParamRefs(String name) {
    if (state is! EditorLoaded) return;
    final controller = (state as EditorLoaded).controller;

    for (final node in controller.nodes.values) {
      final paramRefs = node.data.paramRefs;
      final fieldKeys = paramRefs.keys.toList();

      for (final fieldKey in fieldKeys) {
        final refName = paramRefs[fieldKey];
        if (refName == name) {
          paramRefs.remove(fieldKey);
        }
      }
    }
  }

  void _renameParamRefs(String oldName, String newName) {
    if (state is! EditorLoaded) {
      return;
    }
    final controller = (state as EditorLoaded).controller;

    for (final node in controller.nodes.values) {
      final paramRefs = node.data.paramRefs;
      final fieldKeys = paramRefs.keys.toList();

      for (final fieldKey in fieldKeys) {
        final refName = paramRefs[fieldKey];

        if (refName != oldName) continue;
        paramRefs[fieldKey] = newName;
      }
    }
  }

  
  Map<String, dynamic> exportToJson() {
    late EditorLoaded loaded;
    if (state is EditorLoaded) {
      loaded = state as EditorLoaded;
    } else {
      throw Exception("Editor must be loaded before export");
    }
    
    final controller = loaded.controller;
    final generator = ExperimentGenerator.assemble(controller.nodes.values.toList(), controller.connections.toList());

    return {
      "generator": generator,
      "param_space": loaded.paramSpace.toJson(),
    };
  }

  void _disposeController() {
    if (state is! EditorLoaded) {
      return;
    }
    (state as EditorLoaded).controller.dispose();
  }


  @override
  Future<void> close() {
    _disposeController();
    return super.close();
  }
}
