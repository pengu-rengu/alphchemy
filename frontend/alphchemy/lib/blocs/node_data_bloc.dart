import "package:alphchemy/model/experiment/node_data.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class NodeDataEvent {
  const NodeDataEvent();
}

class UpdateNodeField extends NodeDataEvent {
  final String field;
  final String text;

  const UpdateNodeField({required this.field, required this.text});
}

class UpdateNodeFieldTyped extends NodeDataEvent {
  final String field;
  final dynamic value;

  const UpdateNodeFieldTyped({required this.field, required this.value});
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
  }

  void _onUpdateField(UpdateNodeField event, Emitter<NodeDataState> emit) {
    nodeData.updateField(event.field, event.text);
    emit(NodeDataState(version: state.version + 1));
  }

  void _onUpdateFieldTyped(UpdateNodeFieldTyped event, Emitter<NodeDataState> emit) {
    nodeData.updateFieldTyped(event.field, event.value);
    emit(NodeDataState(version: state.version + 1));
  }
}
