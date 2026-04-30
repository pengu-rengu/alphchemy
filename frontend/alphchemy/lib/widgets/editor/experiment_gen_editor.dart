import "dart:convert";

import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/model/generator/editor_tree_item.dart";
import "package:alphchemy/model/generator/node_data.dart";
import "package:alphchemy/widgets/editor/node_content/node_content.dart";
import "package:alphchemy/widgets/editor/param_sidebar.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ExperimentGenEditor extends StatelessWidget {
  const ExperimentGenEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      buildWhen: (previous, current) {
        if (previous is! EditorLoaded && current is EditorLoaded) return true;
        if (previous is EditorLoaded && current is! EditorLoaded) return true;
        if (previous is! EditorLoaded || current is! EditorLoaded) return false;
        return previous.treeVersion != current.treeVersion;
      },
      builder: (context, state) {
        if (state is! EditorLoaded) {
          return const SizedBox();
        }

        return Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  const TreeEditor(),
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
              )
            ),
            const VerticalDivider(),
            const SizedBox(width: 280, child: ParamSidebar())
          ]
        );
      }
    );
  }
}

class TreeEditor extends StatelessWidget {

  const TreeEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<EditorBloc>().state as EditorLoaded;

    return CustomScrollView(
      slivers: [
        TreeSliver<EditorTreeItem>(
          tree: state.tree,
          toggleAnimationStyle: AnimationStyle.noAnimation,
          treeRowExtentBuilder: (node, dimensions) {
            final item = node.content as EditorTreeItem;

            return item.rowExtent;
          },
          treeNodeBuilder: (context, node, animationStyle) {
            final item = node.content as EditorTreeItem;

            return switch (item) {
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
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              ToggleButton(node: node),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  nodeData.nodeType.value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold
                  ),
                  overflow: TextOverflow.ellipsis
                )
              ),
              if (nodeData.nodeType != NodeType.experimentGen)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final event = RemoveTreeNode(nodeId: nodeData.nodeId);
                    context.read<EditorBloc>().add(event);
                  }
                )
            ]
          )
        )
      )
    );
  }
}

class FieldsRow extends StatelessWidget {
  final FieldsTreeItem item;

  const FieldsRow({
    super.key,
    required this.item
  });

  @override
  Widget build(BuildContext context) {
    final nodeData = item.nodeData;

    return BlocProvider(
      key: ValueKey<String>("bloc_${nodeData.nodeId}"),
      create: (_) => NodeDataBloc(nodeData: nodeData),
      child: SizedBox(
        height: item.rowExtent,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: NodeFields(nodeData: nodeData)
            )
          )
        )
      )
    );
  }
}

class SlotRow extends StatelessWidget {
  final TreeSliverNode<Object?> node;
  final SlotTreeItem item;

  const SlotRow({
    super.key,
    required this.node,
    required this.item
  });

  @override
  Widget build(BuildContext context) {
    final childCount = item.parent.childrenInSlot(item.slot.key).length;
    final label = "${item.slot.label} ($childCount)";

    return SizedBox(
      height: item.rowExtent,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              ToggleButton(node: node),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600
                  ),
                  overflow: TextOverflow.ellipsis
                )
              ),
              AddChildButton(item: item)
            ]
          )
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
      return const SizedBox(width: 28, height: 28);
    }

    final icon = node.isExpanded ? Icons.expand_more : Icons.chevron_right;

    return TreeSliver.wrapChildToToggleNode(
      node: node,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(icon, size: 18)
      )
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
      return const SizedBox(width: 28, height: 28);
    }

    return PopupMenuButton<ChildOption>(
      tooltip: "Add child",
      icon: const Icon(Icons.add, size: 18),
      onSelected: (option) {
        final event = AddTreeChild(
          parentId: item.parent.nodeId,
          slotKey: option.slot.key,
          nodeType: option.nodeType
        );
        context.read<EditorBloc>().add(event);
      },
      itemBuilder: (context) {
        return options.map((option) {
          final label = "${option.slot.label}: ${option.nodeType.value}";

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
