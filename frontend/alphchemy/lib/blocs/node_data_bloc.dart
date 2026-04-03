import "package:alphchemy/objects/node_object.dart";
import "package:flutter/widgets.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

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
    on<UpdateNodeField>(_onUpdateField);
    on<UpdateNodeFieldTyped>(_onUpdateFieldTyped);
    on<UpdateNodeParamRef>(_onUpdateParamRef);
    on<NodeDataResize>(_onResize);
  }

  void _onUpdateField(UpdateNodeField event, Emitter<NodeDataState> emit) {
    node.data.updateField(event.fieldKey, event.text);
    emit(NodeDataState(version: state.version + 1));
  }

  void _onUpdateFieldTyped(UpdateNodeFieldTyped event, Emitter<NodeDataState> emit) {
    node.data.updateFieldTyped(event.fieldKey, event.value);
    emit(NodeDataState(version: state.version + 1));
  }

  void _onUpdateParamRef(UpdateNodeParamRef event, Emitter<NodeDataState> emit) {
    if (event.paramName == null) {
      node.data.paramRefs.remove(event.fieldKey);
    } else {
      node.data.paramRefs[event.fieldKey] = event.paramName!;
    }
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
