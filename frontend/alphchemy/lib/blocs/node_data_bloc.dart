import "package:alphchemy/model/generator/node_data.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class NodeDataEvent {
  const NodeDataEvent();
}

class UpdateNodeField extends NodeDataEvent {
  final String fieldKey;
  final String text;

  const UpdateNodeField({required this.fieldKey, required this.text});
}

class UpdateNodeFieldTyped extends NodeDataEvent {
  final String fieldKey;
  final dynamic value;

  const UpdateNodeFieldTyped({required this.fieldKey, required this.value});
}

class UpdateNodeParamRef extends NodeDataEvent {
  final String fieldKey;
  final String? paramName;

  const UpdateNodeParamRef({required this.fieldKey, required this.paramName});
}

class NodeDataState {
  final int version;

  const NodeDataState({this.version = 0});
}

class NodeDataBloc extends Bloc<NodeDataEvent, NodeDataState> {
  final NodeData nodeData;

  NodeDataBloc({required this.nodeData}) : super(const NodeDataState()) {
    on<UpdateNodeField>(_onUpdateField);
    on<UpdateNodeFieldTyped>(_onUpdateFieldTyped);
    on<UpdateNodeParamRef>(_onUpdateParamRef);
  }

  void _onUpdateField(UpdateNodeField event, Emitter<NodeDataState> emit) {
    nodeData.updateField(event.fieldKey, event.text);
    emit(NodeDataState(version: state.version + 1));
  }

  void _onUpdateFieldTyped(UpdateNodeFieldTyped event, Emitter<NodeDataState> emit) {
    nodeData.updateFieldTyped(event.fieldKey, event.value);
    emit(NodeDataState(version: state.version + 1));
  }

  void _onUpdateParamRef(UpdateNodeParamRef event, Emitter<NodeDataState> emit) {
    if (event.paramName == null) {
      nodeData.paramRefs.remove(event.fieldKey);
    } else {
      nodeData.paramRefs[event.fieldKey] = event.paramName!;
    }
    emit(NodeDataState(version: state.version + 1));
  }
}
