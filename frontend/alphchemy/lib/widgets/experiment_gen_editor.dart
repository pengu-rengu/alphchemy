import "dart:convert";

import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/widgets/node_content.dart";
import "package:alphchemy/widgets/param_sidebar.dart";
import "package:flutter/material.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";
import "package:flutter_bloc/flutter_bloc.dart";


const _nodeCategories = <String, List<String>>{
  "Experiment": ["backtest_schema", "strategy_gen"],
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
      events: NodeFlowEvents(
        node: NodeEvents<NodeObject>(
          onBeforeDelete: (node) async {
            return node.type != "experiment_gen";
          }
        ),
        connection: ConnectionEvents<NodeObject, void>(
          onBeforeComplete: (ctx) {
            final sourceType = ctx.sourceNode.type;
            final portId = ctx.sourcePort.id;
            final targetType = ctx.targetNode.type;
            final allowed = canConnect(sourceType, portId, targetType);
            if (allowed) return ConnectionValidationResult.allow();
            return ConnectionValidationResult.deny(showMessage: true);
          }
        )
      ),
      theme: NodeFlowTheme.dark.copyWith(
        connectionTheme: ConnectionTheme.dark.copyWith(
          style: ConnectionStyles.bezier
        ),
        portTheme: PortTheme.dark.copyWith(
          labelTextStyle: Theme.of(context).textTheme.bodyMedium
        )
      ),
      nodeBuilder: (context, node) => NodeContent(node: node)
    );
  }
}

class ExperimentGenEditor extends StatelessWidget {
  const ExperimentGenEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      buildWhen: (prev, curr) {
        if (prev.runtimeType != curr.runtimeType) return true;
        if (prev is! EditorLoaded) return false;
        if (curr is! EditorLoaded) return false;
        return !identical(prev.controller, curr.controller);
      },
      builder: (context, state) {
        if (state is! EditorLoaded) {
          return SizedBox();
        }
        return Row(
          children: [
            Expanded(
              child: Stack(
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
                        context.read<EditorBloc>().add(AddNode(nodeType: nodeType));
                      },
                      child: Icon(Icons.add)
                    )
                  ),
                  Positioned(
                    right: 80,
                    bottom: 16,
                    child: FloatingActionButton(
                      onPressed: () {
                        final bloc = context.read<EditorBloc>();
                        final json = bloc.exportToJson();
                        final encoded = JsonEncoder.withIndent("  ").convert(json);
                        showDialog(
                          context: context,
                          builder: (_) => DebugJsonDialog(json: encoded)
                        );
                      },
                      child: Icon(Icons.bug_report)
                    )
                  )
                ]
              )
            ),
            VerticalDivider(),
            SizedBox(
              width: 280,
              child: ParamSidebar()
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

class DebugJsonDialog extends StatelessWidget {
  final String json;

  const DebugJsonDialog({super.key, required this.json});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Assembled JSON",
              style: Theme.of(context).textTheme.titleMedium
            ),
            SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  json,
                  style: TextStyle(
                    fontFamily: "monospace",
                    fontSize: 12
                  )
                )
              )
            ),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("Close")
              )
            )
          ]
        )
      )
    );
  }
}
