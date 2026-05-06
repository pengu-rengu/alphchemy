import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/experiment/editor_tree_item.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:flutter/widgets.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class EditorEvent {
  const EditorEvent();
}

class LoadTreeFromJson extends EditorEvent {
  final Map<String, dynamic> json;

  const LoadTreeFromJson({required this.json});
}

class AddTreeChild extends EditorEvent {
  final String parentId;
  final String slotKey;
  final NodeType nodeType;

  const AddTreeChild({
    required this.parentId,
    required this.slotKey,
    required this.nodeType
  });
}

class RemoveTreeNode extends EditorEvent {
  final String nodeId;

  const RemoveTreeNode({required this.nodeId});
}

sealed class EditorState {
  const EditorState();
}

class EditorInitial extends EditorState {
  const EditorInitial();
}

class EditorLoaded extends EditorState {
  final Experiment root;
  final List<TreeSliverNode<EditorTreeItem>> tree;
  final int treeVersion;

  const EditorLoaded({
    required this.root,
    required this.tree,
    this.treeVersion = 0
  });

  EditorLoaded copyWith({
    Experiment? root,
    List<TreeSliverNode<EditorTreeItem>>? tree,
    int? treeVersion
  }) {
    return EditorLoaded(
      root: root ?? this.root,
      tree: tree ?? this.tree,
      treeVersion: treeVersion ?? this.treeVersion
    );
  }
}

class EditorError extends EditorState {
  final String message;

  const EditorError({required this.message});
}

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc() : super(const EditorInitial()) {
    on<LoadTreeFromJson>(_onLoadTree);
    on<AddTreeChild>(_onAddChild);
    on<RemoveTreeNode>(_onRemoveTreeNode);
  }

  void _onLoadTree(LoadTreeFromJson event, Emitter<EditorState> emit) {
    final root = Experiment.fromJson(event.json);
    final tree = <TreeSliverNode<EditorTreeItem>>[_createNode(root, null)];

    final newState = EditorLoaded(root: root, tree: tree);
    emit(newState);
  }

  void _onAddChild(AddTreeChild event, Emitter<EditorState> emit) {
    final loaded = _loadedOrNull();
    if (loaded == null) return;

    final parent = loaded.root.find(event.parentId);
    if (parent == null) return;

    final child = Experiment.createEmptyNode(event.nodeType);
    final added = parent.addChild(event.slotKey, child);
    if (!added) return;

    final expandedKeys = _collectExpandedKeys(loaded.tree);
    final slotRowKey = "slot_${event.parentId}_${event.slotKey}";
    expandedKeys.add(slotRowKey);

    final newTree = <TreeSliverNode<EditorTreeItem>>[_createNode(loaded.root, expandedKeys)];
    final newState = loaded.copyWith(tree: newTree, treeVersion: loaded.treeVersion + 1);
    emit(newState);
  }

  void _onRemoveTreeNode(RemoveTreeNode event, Emitter<EditorState> emit) {
    final loaded = _loadedOrNull();
    if (loaded == null) return;
    if (event.nodeId == loaded.root.nodeId) return;

    loaded.root.removeChild(event.nodeId);

    final expandedKeys = _collectExpandedKeys(loaded.tree);
    final newTree = <TreeSliverNode<EditorTreeItem>>[_createNode(loaded.root, expandedKeys)];
    final newState = loaded.copyWith(tree: newTree, treeVersion: loaded.treeVersion + 1);
    emit(newState);
  }

  Map<String, dynamic> exportToJson() {
    final loaded = _loadedOrNull();
    if (loaded == null) {
      throw Exception("Editor must be loaded before export");
    }

    return loaded.root.toJson();
  }

  EditorLoaded? _loadedOrNull() {
    if (state is! EditorLoaded) return null;
    return state as EditorLoaded;
  }

  TreeSliverNode<EditorTreeItem> _createNode(NodeData data, Set<String>? expandedKeys) {
    final childNodes = <TreeSliverNode<EditorTreeItem>>[];

    if (data.fieldCount > 0) {
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

  TreeSliverNode<EditorTreeItem> _createSlotNode(NodeData parent, ChildSlot slot, Set<String>? expandedKeys) {
    final childNodes = <TreeSliverNode<EditorTreeItem>>[];
    final children = parent.childrenInSlot(slot.key);

    for (final child in children) {
      childNodes.add(_createNode(child, expandedKeys));
    }

    final item = SlotTreeItem(parent: parent, slot: slot);
    return TreeSliverNode<EditorTreeItem>(
      item,
      children: childNodes,
      expanded: _isExpanded(expandedKeys, item.rowKey)
    );
  }

  bool _isExpanded(Set<String>? expandedKeys, String rowKey) {
    if (expandedKeys == null) return true;
    return expandedKeys.contains(rowKey);
  }

  Set<String> _collectExpandedKeys(List<TreeSliverNode<EditorTreeItem>> nodes) {
    final keys = <String>{};
    _collectExpandedKeysInto(nodes, keys);
    return keys;
  }

  void _collectExpandedKeysInto(List<TreeSliverNode<EditorTreeItem>> nodes, Set<String> keys) {
    for (final node in nodes) {
      if (node.isExpanded) {
        keys.add(node.content.rowKey);
      }
      _collectExpandedKeysInto(node.children, keys);
    }
  }
}
