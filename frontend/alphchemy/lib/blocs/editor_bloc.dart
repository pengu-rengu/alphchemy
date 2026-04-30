import "package:alphchemy/model/generator/experiment.dart";
import "package:alphchemy/model/generator/editor_tree_item.dart";
import "package:alphchemy/model/generator/node_data.dart";
import "package:alphchemy/model/generator/param_space.dart";
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

class AddParam extends EditorEvent {
  final Param param;

  const AddParam({required this.param});
}

class UpdateParamValues extends EditorEvent {
  final String name;
  final String text;

  const UpdateParamValues({required this.name, required this.text});
}

class UpdateParamType extends EditorEvent {
  final String name;
  final ParamType type;

  const UpdateParamType({required this.name, required this.type});
}

class RenameParam extends EditorEvent {
  final String oldName;
  final String newName;

  const RenameParam({required this.oldName, required this.newName});
}

class RemoveParam extends EditorEvent {
  final String name;

  const RemoveParam({required this.name});
}

sealed class EditorState {
  const EditorState();
}

class EditorInitial extends EditorState {
  const EditorInitial();
}

class EditorLoaded extends EditorState {
  final ExperimentGenerator root;
  final List<TreeSliverNode<EditorTreeItem>> tree;
  final ParamSpace paramSpace;
  final int treeVersion;
  final int paramVersion;

  const EditorLoaded({
    required this.root,
    required this.tree,
    required this.paramSpace,
    this.treeVersion = 0,
    this.paramVersion = 0
  });

  EditorLoaded copyWith({
    ExperimentGenerator? root,
    List<TreeSliverNode<EditorTreeItem>>? tree,
    ParamSpace? paramSpace,
    int? treeVersion,
    int? paramVersion
  }) {
    return EditorLoaded(
      root: root ?? this.root,
      tree: tree ?? this.tree,
      paramSpace: paramSpace ?? this.paramSpace,
      treeVersion: treeVersion ?? this.treeVersion,
      paramVersion: paramVersion ?? this.paramVersion
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
    on<AddParam>(_onAddParam);
    on<UpdateParamValues>(_onUpdateParamValues);
    on<UpdateParamType>(_onUpdateParamType);
    on<RenameParam>(_onRenameParam);
    on<RemoveParam>(_onRemoveParam);
  }

  void _onLoadTree(LoadTreeFromJson event, Emitter<EditorState> emit) {
    final generatorJson = event.json["generator"] as Map<String, dynamic>? ?? {};
    final paramSpaceJson = event.json["param_space"] as Map<String, dynamic>? ?? {"search_space": <String, dynamic>{}};
    final root = ExperimentGenerator.fromJson(generatorJson);
    final tree = <TreeSliverNode<EditorTreeItem>>[_createNode(root, null)];
    final paramSpace = ParamSpace.fromJson(paramSpaceJson);

    final newState = EditorLoaded(root: root, tree: tree, paramSpace: paramSpace);
    emit(newState);
  }

  void _onAddChild(AddTreeChild event, Emitter<EditorState> emit) {
    final loaded = _loadedOrNull();
    if (loaded == null) return;

    final parent = loaded.root.find(event.parentId);
    if (parent == null) return;

    final child = ExperimentGenerator.createEmptyNode(event.nodeType);
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

  void _onAddParam(AddParam event, Emitter<EditorState> emit) {
    final loaded = _loadedOrNull();
    if (loaded == null) return;

    final paramSpace = loaded.paramSpace.copy();
    final added = paramSpace.addParam(event.param);
    if (!added) return;

    _emitParamSpace(emit, loaded, paramSpace);
  }

  void _onUpdateParamValues(UpdateParamValues event, Emitter<EditorState> emit) {
    final loaded = _loadedOrNull();
    if (loaded == null) return;

    final paramSpace = loaded.paramSpace.copy();
    paramSpace.updateParamValues(event.name, event.text);
    _emitParamSpace(emit, loaded, paramSpace);
  }

  void _onUpdateParamType(UpdateParamType event, Emitter<EditorState> emit) {
    final loaded = _loadedOrNull();
    if (loaded == null) return;

    final paramSpace = loaded.paramSpace.copy();
    paramSpace.updateParamType(event.name, event.type);
    _clearParamRefs(loaded.root, event.name);
    _emitParamSpace(emit, loaded, paramSpace);
  }

  void _onRenameParam(RenameParam event, Emitter<EditorState> emit) {
    final loaded = _loadedOrNull();
    if (loaded == null) return;

    final paramSpace = loaded.paramSpace.copy();
    final renamed = paramSpace.renameParam(event.oldName, event.newName);
    if (!renamed) return;

    _renameParamRefs(loaded.root, event.oldName, event.newName);
    _emitParamSpace(emit, loaded, paramSpace);
  }

  void _onRemoveParam(RemoveParam event, Emitter<EditorState> emit) {
    final loaded = _loadedOrNull();
    if (loaded == null) return;

    final paramSpace = loaded.paramSpace.copy();
    paramSpace.removeParam(event.name);
    _clearParamRefs(loaded.root, event.name);
    _emitParamSpace(emit, loaded, paramSpace);
  }

  Map<String, dynamic> exportToJson() {
    final loaded = _loadedOrNull();
    if (loaded == null) {
      throw Exception("Editor must be loaded before export");
    }

    return {
      "generator": loaded.root.toJson(),
      "param_space": loaded.paramSpace.toJson()
    };
  }

  EditorLoaded? _loadedOrNull() {
    if (state is! EditorLoaded) return null;
    return state as EditorLoaded;
  }

  void _emitParamSpace(Emitter<EditorState> emit, EditorLoaded loaded, ParamSpace paramSpace) {
    final newState = loaded.copyWith(
      paramSpace: paramSpace,
      paramVersion: loaded.paramVersion + 1
    );
    emit(newState);
  }

  void _clearParamRefs(NodeData root, String name) {
    root.visitChildren((object) {
      final fieldKeys = object.paramRefs.keys.toList();

      for (final fieldKey in fieldKeys) {
        final refName = object.paramRefs[fieldKey];
        if (refName == name) {
          object.paramRefs.remove(fieldKey);
        }
      }
    });
  }

  void _renameParamRefs(NodeData root, String oldName, String newName) {
    root.visitChildren((object) {
      final fieldKeys = object.paramRefs.keys.toList();

      for (final fieldKey in fieldKeys) {
        final refName = object.paramRefs[fieldKey];
        if (refName != oldName) continue;
        object.paramRefs[fieldKey] = newName;
      }
    });
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
