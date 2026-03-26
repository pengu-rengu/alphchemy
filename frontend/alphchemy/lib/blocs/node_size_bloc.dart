import "package:alphchemy/objects/node_object.dart";
import "package:flutter/widgets.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

sealed class NodeSizeEvent {
  const NodeSizeEvent();
}

class MeasureRequested extends NodeSizeEvent {
  const MeasureRequested();
}

class NodeSizeState {
  const NodeSizeState();
}

class NodeSizeBloc extends Bloc<NodeSizeEvent, NodeSizeState> {
  final GlobalKey contentKey = GlobalKey();
  final Node<NodeObject> node;

  NodeSizeBloc({required this.node}) : super(const NodeSizeState()) {
    on<MeasureRequested>(_onMeasure);
  }

  void _onMeasure(MeasureRequested event, Emitter<NodeSizeState> emit) {
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
    final portArea = outputs.length * 25.0;
    final height = contentSize.height + portArea;

    node.setSize(Size(contentSize.width, height));

    for (final port in node.ports) {
      if (port.type != PortType.input) continue;
      final updated = port.copyWith(offset: Offset(0, height / 2));
      node.updatePort(port.id, updated);
    }

    for (var i = 0; i < outputs.length; i++) {
      final yPos = contentSize.height + i * 25.0;
      final updated = outputs[i].copyWith(offset: Offset(0, yPos));
      node.updatePort(outputs[i].id, updated);
    }
  }
}
