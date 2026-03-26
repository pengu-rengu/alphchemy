import "package:flutter_bloc/flutter_bloc.dart";

sealed class NodeDataEvent {
  const NodeDataEvent();
}

class NodeDataChanged extends NodeDataEvent {
  const NodeDataChanged();
}

class NodeDataState {
  final int version;

  const NodeDataState({this.version = 0});
}

class NodeDataBloc extends Bloc<NodeDataEvent, NodeDataState> {
  NodeDataBloc() : super(const NodeDataState()) {
    on<NodeDataChanged>(_onChanged);
  }

  void _onChanged(NodeDataChanged event, Emitter<NodeDataState> emit) {
    final newState = NodeDataState(version: state.version + 1);
    emit(newState);
  }
}
