import "package:alphchemy/blocs/node_editor_bloc.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/widgets/node_content.dart";
import "package:flutter/material.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";
import "package:flutter_bloc/flutter_bloc.dart";


const _nodeCategories = <String, List<String>>{
  "Experiment": ["backtest_schema"],
  "Network": [
    "network_gen",
    "logic_net",
    "decision_net",
    "input_node",
    "gate_node",
    "branch_node",
    "ref_node"
  ],
  "Features": ["constant_feature", "raw_returns_feature"],
  "Actions": [
    "actions_gen",
    "logic_actions",
    "decision_actions",
    "meta_action",
    "threshold_range"
  ],
  "Penalties": ["penalties_gen", "logic_penalties", "decision_penalties"],
  "Optimizer": ["stop_conds", "genetic_opt"],
  "Schema": ["entry_schema", "exit_schema", "node_ptr"]
};

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
      theme: NodeFlowTheme.dark.copyWith(
      connectionTheme: ConnectionTheme.dark.copyWith(
        style: ConnectionStyles.bezier
      ),
      portTheme: PortTheme.dark.copyWith(
        labelTextStyle: Theme.of(context).textTheme.bodyMedium
      )),
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
        return Stack(
          children: [
            NodeEditor(controller: state.controller),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () async {
                  final nodeType = await showDialog<String>(
                    context: context,
                    builder: (_) => AddNodeDialog()
                  );
                  if (nodeType == null) return;
                  if (!context.mounted) return;
                  context.read<NodeEditorBloc>().add(
                    AddNode(nodeType: nodeType)
                  );
                },
                child: Icon(Icons.add)
              )
            )
          ]
        );
      }
    );
  }
}

class AddNodeDialog extends StatelessWidget {
  const AddNodeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text("Add Node"),
      children: _nodeCategories.entries.expand((entry) {
        final category = entry.key;
        final types = entry.value;
        return [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Text(
              category,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70
              )
            )
          ),
          ...types.map((nodeType) {
            return SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(nodeType),
              child: Text(nodeType)
            );
          })
        ];
      }).toList()
    );
  }
}
