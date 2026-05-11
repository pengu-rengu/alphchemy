import "dart:convert";

import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/model/experiment/editor_tree_item.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:alphchemy/widgets/padded_card.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ExperimentEditor extends StatelessWidget {
  const ExperimentEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        return Stack(
          children: [
            // IMPOTANT NOTE TO CODEX AND CLAUDE: DO NOT ADD CONST MODIFIERS HERE
            // ignore: prefer_const_constructors
            TreeEditor(),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: "debug_json_fab",
                onPressed: () {
                  final bloc = context.read<EditorBloc>();
                  final json = bloc.exportToJson();
                  final encoded = const JsonEncoder.withIndent("  ").convert(json);
                  showDialog(
                    context: context,
                    builder: (_) => DebugJsonDialog(json: encoded)
                  );
                },
                child: const Icon(Icons.bug_report)
              )
            )
          ]
        );
      }
    );
  }
}

class TreeEditor extends StatelessWidget {
  static const double treeIndent = 10.0;

  const TreeEditor({super.key});

  @override
  Widget build(BuildContext context) {
    
    return CustomScrollView(
      slivers: [
        TreeSliver<EditorTreeItem>(
          tree: context.read<EditorBloc>().state.tree,
          indentation: TreeSliverIndentationType.none,
          toggleAnimationStyle: AnimationStyle.noAnimation,
          treeRowExtentBuilder: (node, dimensions) {
            final item = node.content as EditorTreeItem;

            return item.rowExtent;
          },
          treeNodeBuilder: (context, node, animationStyle) {
            final item = node.content as EditorTreeItem;
            final row = switch (item) {
              HeaderTreeItem() => HeaderRow(
                key: ValueKey<String>(item.rowKey),
                node: node,
                item: item
              ),
              FieldsTreeItem() => FieldsRow(
                key: ValueKey<String>(item.rowKey),
                item: item
              ),
              SlotTreeItem() => SlotRow(
                key: ValueKey<String>(item.rowKey),
                node: node,
                item: item
              )
            };

            return Padding(
              padding: EdgeInsets.only(left: node.depth! * treeIndent),
              child: row
            );
          }
        )
      ]
    );
  }
}

class HeaderRow extends StatelessWidget {
  final TreeSliverNode<Object?> node;
  final HeaderTreeItem item;

  const HeaderRow({super.key, required this.node, required this.item});

  @override
  Widget build(BuildContext context) {
    final nodeData = item.nodeData;

    return SizedBox(
      height: item.rowExtent,
      child: PaddedCard(
        child: Row(
          children: [
            ToggleButton(node: node),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                nodeData.nodeType.value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold
                ),
                overflow: TextOverflow.ellipsis
              )
            ),
            if (nodeData.nodeType != NodeType.experiment)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  final event = RemoveTreeNode(nodeId: nodeData.nodeId);
                  context.read<EditorBloc>().add(event);
                }
              )
          ]
        )
      )
    );
  }
}

class FieldsRow extends StatelessWidget {
  final FieldsTreeItem item;

  const FieldsRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final nodeData = item.nodeData;

    return BlocProvider(
      key: ValueKey<String>("bloc_${nodeData.nodeId}"),
      create: (_) => NodeDataBloc(nodeData: nodeData),
      child: SizedBox(
        height: item.rowExtent,
        child: PaddedCard(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: NodeFields(nodeData: nodeData)
          )
        )
      )
    );
  }
}

class SlotRow extends StatelessWidget {
  final TreeSliverNode<Object?> node;
  final SlotTreeItem item;

  const SlotRow({super.key, required this.node, required this.item});

  @override
  Widget build(BuildContext context) {
    final slot = item.slot;
    var label = slot.label;

    if (slot.isMulti) {
      label += "  (${item.parent.childrenInSlot(slot.field).length})";
    }

    return SizedBox(
      height: item.rowExtent,
      child: PaddedCard(
        child: Row(
          children: [
            ToggleButton(node: node),
            const SizedBox(width: 5),
            Text(label),
            AddChildButton(item: item)
          ]
        )
      )
    );
  }
}

class ToggleButton extends StatelessWidget {
  final TreeSliverNode<Object?> node;

  const ToggleButton({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    if (node.children.isEmpty) {
      return const SizedBox();
    }

    final icon = node.isExpanded ? Icons.expand_more : Icons.chevron_right;

    return TreeSliver.wrapChildToToggleNode(
      node: node,
      child: Icon(icon, size: 20)
    );
  }
}

class AddChildButton extends StatelessWidget {
  final SlotTreeItem item;

  const AddChildButton({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final options = item.parent.childOptions(item.slot);
    if (options.isEmpty) {
      return const SizedBox();
    }

    return PopupMenuButton<ChildOption>(
      tooltip: "Add child",
      icon: const Icon(Icons.add, size: 20),
      onSelected: (option) {
        final event = AddTreeChild(
          parentId: item.parent.nodeId,
          field: option.slot.field,
          nodeType: option.nodeType
        );
        context.read<EditorBloc>().add(event);
      },
      itemBuilder: (context) {
        return options.map((option) {
          final label = option.nodeType.value;

          return PopupMenuItem<ChildOption>(
            value: option,
            child: Text(label)
          );
        }).toList();
      }
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Assembled JSON",
              style: Theme.of(context).textTheme.titleMedium
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  json,
                  style: const TextStyle(fontFamily: "monospace", fontSize: 12)
                )
              )
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Close")
              )
            )
          ]
        )
      )
    );
  }
}
