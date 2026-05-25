import "package:alphchemy/blocs/experiments/editor_bloc.dart";
import "package:alphchemy/blocs/experiments/node_data_bloc.dart";
import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/model/experiment/tree_item.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_bloc/flutter_bloc.dart";

bool _isExpanded(Set<String>? expandedKeys, String rowKey) {
  if (expandedKeys == null) return true;
  return expandedKeys.contains(rowKey);
}

TreeSliverNode<TreeItem> createSlotNode(NodeData parent, ChildSlot slot, Set<String>? expandedKeys) {
  final childNodes = <TreeSliverNode<TreeItem>>[];
  final children = parent.childrenInSlot(slot.field);

  for (final child in children) {
    final newNode = createTreeNode(child, expandedKeys);
    childNodes.add(newNode);
  }

  final item = SlotTreeItem(parent: parent, slot: slot);
  return TreeSliverNode<TreeItem>(
    item,
    children: childNodes,
    expanded: _isExpanded(expandedKeys, item.rowKey)
  );
}

TreeSliverNode<TreeItem> createTreeNode(NodeData data, Set<String>? expandedKeys) {
  final childNodes = <TreeSliverNode<TreeItem>>[];

  if (data.fields.isNotEmpty) {
    final fieldsItem = FieldsTreeItem(nodeData: data);
    final fieldsNode = TreeSliverNode<TreeItem>(
      fieldsItem,
      expanded: _isExpanded(expandedKeys, fieldsItem.rowKey)
    );
    childNodes.add(fieldsNode);
  }

  for (final slot in data.childSlots) {
    final slotNode = createSlotNode(data, slot, expandedKeys);
    childNodes.add(slotNode);
  }

  final item = HeaderTreeItem(nodeData: data);
  return TreeSliverNode<TreeItem>(
    item,
    children: childNodes,
    expanded: _isExpanded(expandedKeys, item.rowKey)
  );
}

List<TreeSliverNode<TreeItem>> buildExperimentTree(Experiment experiment) {
  return [createTreeNode(experiment, null)];
}

void _collectExpandedKeysInto(List<TreeSliverNode<TreeItem>> nodes, Set<String> keys) {
  for (final node in nodes) {
    if (node.isExpanded) {
      keys.add(node.content.rowKey);
    }
    _collectExpandedKeysInto(node.children, keys);
  }
}

Set<String> collectExpandedKeys(List<TreeSliverNode<TreeItem>> nodes) {
  final keys = <String>{};
  _collectExpandedKeysInto(nodes, keys);
  return keys;
}

class ToggleButton extends StatelessWidget {
  final TreeSliverNode<Object?> node;

  const ToggleButton({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    return node.children.isEmpty
      ? const SizedBox()
      : TreeSliver.wrapChildToToggleNode(
          node: node,
          child: NormalIcon(node.isExpanded ? Icons.expand_more : Icons.chevron_right)
        );
  }
}

class AddChildButton extends StatelessWidget {
  final SlotTreeItem item;
  final bool readOnly;

  const AddChildButton({super.key, required this.item, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      return const SizedBox();
    }
    final options = item.parent.childOptions(item.slot);

    return options.isEmpty
      ? const SizedBox()
      : PopupMenuButton<ChildOption>(
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

class FieldsView extends StatelessWidget {
  final NodeData nodeData;

  const FieldsView({super.key, required this.nodeData});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: (() {
        final widgets = <Widget>[];

        for (final fieldWidget in nodeData.fields) {
          final entry = entryFor(fieldWidget);
          if (entry == null) {
            continue;
          }

          if (widgets.isNotEmpty) {
            widgets.add(const SizedBox(height: 10));
          }

          final value = nodeData.formatField(entry.field);
          final row = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 200, child: NormalText(entry.label)),
              Expanded(child: NormalText(value))
            ]
          );
          widgets.add(row);
        }

        return widgets;
      })(),
    );
  }

  ({String label, String field})? entryFor(Widget fieldWidget) {
    return switch (fieldWidget) {
      NodeTextField() => (label: fieldWidget.label, field: fieldWidget.field),
      NodeDropdown() => (label: fieldWidget.label, field: fieldWidget.field),
      NodeBoolDropdown() => (label: fieldWidget.label, field: fieldWidget.field),
      NodeDateTimeField() => (label: fieldWidget.label, field: fieldWidget.field),
      _ => null
    };
  }
}

class HeaderRow extends StatelessWidget {
  final TreeSliverNode<Object?> node;
  final HeaderTreeItem item;
  final bool readOnly;

  const HeaderRow({super.key, required this.node, required this.item, required this.readOnly});

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
            if (!readOnly && nodeData.nodeType != NodeType.experiment)
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
  final bool readOnly;

  const FieldsRow({super.key, required this.item, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final nodeData = item.nodeData;

    if (readOnly) {
      return SizedBox(
        height: item.rowExtent,
        child: PaddedCard(child: FieldsView(nodeData: nodeData))
      );
    }

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
  final bool readOnly;

  const SlotRow({super.key, required this.node, required this.item, required this.readOnly});

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
            AddChildButton(item: item, readOnly: readOnly)
          ]
        )
      )
    );
  }
}

class ExperimentTree extends StatelessWidget {
  final List<TreeSliverNode<TreeItem>> tree;
  final bool readOnly;

  const ExperimentTree({super.key, required this.tree, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      TreeSliver<TreeItem>(
        tree: tree,
        indentation: TreeSliverIndentationType.none,
        toggleAnimationStyle: AnimationStyle.noAnimation,
        treeRowExtentBuilder: (node, dimensions) {
          final item = node.content as TreeItem;

          return item.rowExtent;
        },
        treeNodeBuilder: (context, node, _) {
          final item = node.content as TreeItem;
          final row = switch (item) {
            HeaderTreeItem() => HeaderRow(
              key: ValueKey<String>(item.rowKey),
              node: node,
              item: item,
              readOnly: readOnly
            ),
            FieldsTreeItem() => FieldsRow(
              key: ValueKey<String>(item.rowKey),
              item: item,
              readOnly: readOnly
            ),
            SlotTreeItem() => SlotRow(
              key: ValueKey<String>(item.rowKey),
              node: node,
              item: item,
              readOnly: readOnly
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
