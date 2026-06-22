/*
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

class NodeDataBloc extends Bloc<NodeDataEvent, NodeData> {
  NodeDataBloc({required NodeData nodeData}) : super(nodeData) {
    on<UpdateNodeField>(_onUpdateField);
    on<UpdateNodeFieldTyped>(_onUpdateFieldTyped);
  }

  void _onUpdateField(UpdateNodeField event, Emitter<NodeData> emit) {
    final newState = state.copy();
    newState.updateField(event.field, event.text);
    emit(newState);
  }

  void _onUpdateFieldTyped(UpdateNodeFieldTyped event, Emitter<NodeData> emit) {
    final newState = state.copy();
    newState.updateFieldTyped(event.field, event.value);
    emit(newState);
  }
}

*/
