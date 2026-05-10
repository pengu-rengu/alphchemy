import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/experiment/editor_tree_item.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:flutter/widgets.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class EditorEvent {
  const EditorEvent();
}

class AddTreeChild extends EditorEvent {
  final String parentId;
  final String field;
  final NodeType nodeType;

  const AddTreeChild({
    required this.parentId,
    required this.field,
    required this.nodeType
  });
}

class RemoveTreeNode extends EditorEvent {
  final String nodeId;

  const RemoveTreeNode({required this.nodeId});
}

class EditorState {
  final Experiment experiment;
  final List<TreeSliverNode<EditorTreeItem>> tree;
  final int treeVersion;

  const EditorState({
    required this.experiment,
    required this.tree,
    this.treeVersion = 0
  });

  EditorState copyWith({Experiment? experiment, List<TreeSliverNode<EditorTreeItem>>? tree, int? treeVersion}) {
    return EditorState(
      experiment: experiment ?? this.experiment,
      tree: tree ?? this.tree,
      treeVersion: treeVersion ?? this.treeVersion
    );
  }
}

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc() : super(_buildInitial()) {
    on<AddTreeChild>(_onAddChild);
    on<RemoveTreeNode>(_onRemoveTreeNode);
  }

  static EditorState _buildInitial() {
    final root = Experiment.fromJson(<String, dynamic>{});
    final tree = <TreeSliverNode<EditorTreeItem>>[_createNode(root, {})];
    return EditorState(experiment: root, tree: tree);
  }

  void _onAddChild(AddTreeChild event, Emitter<EditorState> emit) {

    final parent = state.experiment.find(event.parentId);
    if (parent == null) return;

    final child = event.nodeType.emptyNode();
    final added = parent.addChild(event.field, child);
    if (!added) return;

    final expandedKeys = _collectExpandedKeys(state.tree);
    final slotRowKey = "slot_${event.parentId}_${event.field}";
    expandedKeys.add(slotRowKey);

    final newTree = <TreeSliverNode<EditorTreeItem>>[_createNode(state.experiment, expandedKeys)];
    final newState = state.copyWith(tree: newTree, treeVersion: state.treeVersion + 1);
    emit(newState);
  }

  void _onRemoveTreeNode(RemoveTreeNode event, Emitter<EditorState> emit) {
    if (event.nodeId == state.experiment.nodeId) return;

    state.experiment.removeChild(event.nodeId);

    final expandedKeys = _collectExpandedKeys(state.tree);
    final newTree = <TreeSliverNode<EditorTreeItem>>[_createNode(state.experiment, expandedKeys)];
    final newState = state.copyWith(tree: newTree, treeVersion: state.treeVersion + 1);
    emit(newState);
  }

  Map<String, dynamic> exportToJson() {
    return state.experiment.toJson();
  }

  static TreeSliverNode<EditorTreeItem> _createNode(NodeData data, Set<String> expandedKeys) {
    final childNodes = <TreeSliverNode<EditorTreeItem>>[];

    if (data.fields.isNotEmpty) {
      final fieldsItem = FieldsTreeItem(nodeData: data);
      final fieldsNode = TreeSliverNode<EditorTreeItem>(
        fieldsItem,
        expanded: _isExpanded(expandedKeys, fieldsItem.rowKey)
      );
      childNodes.add(fieldsNode);
    }

    for (final slot in data.childSlots) {
      final slotNode = _createSlotNode(data, slot, expandedKeys);
      childNodes.add(slotNode);
    }

    final item = HeaderTreeItem(nodeData: data);
    return TreeSliverNode<EditorTreeItem>(
      item,
      children: childNodes,
      expanded: _isExpanded(expandedKeys, item.rowKey)
    );
  }

  static TreeSliverNode<EditorTreeItem> _createSlotNode(NodeData parent, ChildSlot slot, Set<String> expandedKeys) {
    final childNodes = <TreeSliverNode<EditorTreeItem>>[];
    final children = parent.childrenInSlot(slot.field);

    for (final child in children) {
      final newNode = _createNode(child, expandedKeys);
      childNodes.add(newNode);
    }

    final item = SlotTreeItem(parent: parent, slot: slot);
    return TreeSliverNode<EditorTreeItem>(
      item,
      children: childNodes,
      expanded: _isExpanded(expandedKeys, item.rowKey)
    );
  }

  static bool _isExpanded(Set<String>? expandedKeys, String rowKey) {
    if (expandedKeys == null) return true;
    return expandedKeys.contains(rowKey);
  }

  static Set<String> _collectExpandedKeys(List<TreeSliverNode<EditorTreeItem>> nodes) {
    final keys = <String>{};
    _collectExpandedKeysInto(nodes, keys);
    return keys;
  }

  static void _collectExpandedKeysInto(List<TreeSliverNode<EditorTreeItem>> nodes, Set<String> keys) {
    for (final node in nodes) {
      if (node.isExpanded) {
        keys.add(node.content.rowKey);
      }
      _collectExpandedKeysInto(node.children, keys);
    }
  }
}
