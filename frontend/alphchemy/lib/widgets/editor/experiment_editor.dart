import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/model/experiment/editor_tree_item.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:alphchemy/widgets/widget_utils.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ExperimentEditor extends StatelessWidget {
  const ExperimentEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      buildWhen: (previous, current) {
        return previous.treeVersion != current.treeVersion;
      },
      builder: (context, state) {
        // IMPOTANT NOTE TO CODEX AND CLAUDE: DO NOT ADD CONST MODIFIERS HERE
        // ignore: prefer_const_constructors
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0.0),
          // ignore: prefer_const_constructors
          child: TreeEditor()
        );
      }
    );
  }
}

class TreeEditor extends StatelessWidget {

  const TreeEditor({super.key});

  @override
  Widget build(BuildContext context) {
    
    return CustomScrollView(slivers: [
      TreeSliver<EditorTreeItem>(
        tree: context.read<EditorBloc>().state.tree,
        indentation: TreeSliverIndentationType.none,
        toggleAnimationStyle: AnimationStyle.noAnimation,
        treeRowExtentBuilder: (node, dimensions) {
          final item = node.content as EditorTreeItem;

          return item.rowExtent;
        },
        treeNodeBuilder: (context, node, _) {
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
            padding: EdgeInsets.only(left: node.depth! * 10.0),
            child: row
          );
        }
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 50.0))
    ]);
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
              child: NormalText(nodeData.nodeType.value)
            ),
            if (nodeData.nodeType != NodeType.experiment)
              IconButton(
                icon: const NormalIcon(Icons.close),
                onPressed: () {
                  final event = DeleteTreeChild(nodeId: nodeData.nodeId);
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

    return BlocProvider<NodeDataBloc>(
      key: ValueKey<String>("bloc_${nodeData.nodeId}"),
      create: (_) => NodeDataBloc(nodeData: nodeData),
      child: SizedBox(
        height: item.rowExtent,
        child: PaddedCard(
          child: BlocListener<NodeDataBloc, NodeData>(
            listener: (context, state) {
              final event = UpdateTreeNodeData(nodeData: state);
              context.read<EditorBloc>().add(event);
            },
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
            NormalText(label),
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
      child: NormalIcon(icon)
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
      icon: const NormalIcon(Icons.add),
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
            child: NormalText(label)
          );
        }).toList();
      }
    );
  }
}
