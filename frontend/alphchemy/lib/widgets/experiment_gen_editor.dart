import "package:alphchemy/blocs/node_editor_bloc.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/widgets/node_content.dart";
import "package:flutter/material.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";
import "package:flutter_bloc/flutter_bloc.dart";

final _theme = NodeFlowTheme.dark.copyWith(
  connectionTheme: ConnectionTheme.dark.copyWith(
    style: ConnectionStyles.bezier
  )
);

class NodeEditor extends StatelessWidget {
  final NodeFlowController<NodeObject, void> controller;

  const NodeEditor({
    super.key,
    required this.controller
  });

  @override
  Widget build(BuildContext context) {
    return NodeFlowEditor<NodeObject, void>(
      controller: controller,
      theme: _theme,
      nodeBuilder: (context, node) => NodeContent(node: node)
    );
  }
}

class ExperimentGenEditor extends StatelessWidget {
  const ExperimentGenEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NodeEditorBloc, NodeEditorState>(
      buildWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
      builder: (context, state) {
        if (state is! NodeEditorLoaded) {
          return SizedBox();
        }
        return NodeEditor(controller: state.controller);
      }
    );
  }
}
