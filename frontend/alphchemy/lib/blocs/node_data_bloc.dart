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
    on<NodeDataResize>(_onResize);
  }

  void _onChanged(NodeDataChanged event, Emitter<NodeDataState> emit) {
    emit(NodeDataState(version: state.version + 1));
  }

  void _onResize(NodeDataResize event, Emitter<NodeDataState> emit) {
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
    final width = node.size.value.width;

    final size = Size(width, height);
    _updateNodeSize(size);
    _updateInputPorts(height);
    _updateOutputPorts(outputs, startHeight, portGap);
  }

  void _updateNodeSize(Size size) {
    if (node.size.value == size) return;
    node.setSize(size);
  }

  void _updateInputPorts(double height) {
    final offset = Offset(0, height / 2);
    for (final port in node.ports) {
      if (port.type != PortType.input) continue;
      _updatePortOffset(port, offset);
    }
  }

  void _updateOutputPorts(List<Port> outputs, double startHeight, double portGap) {
    for (var i = 0; i < outputs.length; i++) {
      final relY = i * portGap;
      final offset = Offset(0, startHeight + relY);
      _updatePortOffset(outputs[i], offset);
    }
  }

  void _updatePortOffset(Port port, Offset offset) {
    if (port.offset == offset) return;
    final updated = port.copyWith(offset: offset);
    node.updatePort(port.id, updated);
  }
}
