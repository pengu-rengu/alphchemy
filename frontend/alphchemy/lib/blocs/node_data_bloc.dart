import "package:alphchemy/objects/node_object.dart";
import "package:flutter/widgets.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

sealed class NodeDataEvent {
  const NodeDataEvent();
}

class NodeDataChanged extends NodeDataEvent {
  const NodeDataChanged();
}

class NodeDataResize extends NodeDataEvent {
  const NodeDataResize();
}

class NodeDataState {
  final int version;

  const NodeDataState({this.version = 0});
}

class NodeDataBloc extends Bloc<NodeDataEvent, NodeDataState> {
  final GlobalKey contentKey = GlobalKey();
  final Node<NodeObject> node;

  NodeDataBloc({required this.node}) : super(const NodeDataState()) {
    on<NodeDataChanged>(_onChanged);
    on<NodeDataResize>(_onMeasure);
  }

  void _onChanged(NodeDataChanged event, Emitter<NodeDataState> emit) {
    emit(NodeDataState(version: state.version + 1));
  }

  void _onMeasure(NodeDataResize event, Emitter<NodeDataState> emit) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = contentKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      _resize(box.size);
    });
  }

  void _resize(Size contentSize) {
    final outputs = node.ports.where((port) {
      return port.type == PortType.output;
    }).toList();

    const portOffset = 10.0;
    const portGap = 25.0;

    final portArea = outputs.length * portGap;
    final startHeight = contentSize.height + portOffset;
    final height = startHeight + portArea;

    final size = Size(contentSize.width, height);
    node.setSize(size);

    for (final port in node.ports) {
      if (port.type != PortType.input) continue;
      final updated = port.copyWith(offset: Offset(0, height / 2));
      node.updatePort(port.id, updated);
    }

    for (var i = 0; i < outputs.length; i++) {
      final relY = i * 25.0;
      final pos = Offset(0, startHeight + relY);
      final updated = outputs[i].copyWith(offset: pos);
      node.updatePort(outputs[i].id, updated);
    }
  }
}
