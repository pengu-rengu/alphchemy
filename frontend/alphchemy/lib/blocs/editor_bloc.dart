import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/experiment/tree_item.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/widgets/experiment_tree.dart";
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

class DeleteTreeChild extends EditorEvent {
  final String nodeId;

  const DeleteTreeChild({required this.nodeId});
}

class UpdateTreeNodeData extends EditorEvent {
  final NodeData nodeData;

  const UpdateTreeNodeData({required this.nodeData});
}

class EditorState {
  final Experiment experiment;
  final List<TreeSliverNode<TreeItem>> tree;
  final int treeVersion;

  const EditorState({
    required this.experiment,
    required this.tree,
    this.treeVersion = 0
  });

  EditorState copyWith({Experiment? experiment, List<TreeSliverNode<TreeItem>>? tree, int? treeVersion}) {
    return EditorState(
      experiment: experiment ?? this.experiment,
      tree: tree ?? this.tree,
      treeVersion: treeVersion ?? this.treeVersion
    );
  }
}

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc({Map<String, dynamic>? initialJson}) : super(_buildInitial(initialJson)) {
    on<AddTreeChild>(_onAddChild);
    on<DeleteTreeChild>(_onDeleteChild);
    on<UpdateTreeNodeData>(_onUpdateNodeData);
  }

  static EditorState _buildInitial(Map<String, dynamic>? json) {
    final root = json == null ? Experiment() : Experiment.fromJson(json);
    final tree = <TreeSliverNode<TreeItem>>[createTreeNode(root, {})];
    return EditorState(experiment: root, tree: tree);
  }

  void _onAddChild(AddTreeChild event, Emitter<EditorState> emit) {

    final parent = state.experiment.find(event.parentId);
    if (parent == null) return;

    final child = event.nodeType.emptyNode();
    final added = parent.addChild(event.field, child);
    if (!added) return;

    final expandedKeys = collectExpandedKeys(state.tree);
    final slotRowKey = "slot_${event.parentId}_${event.field}";
    expandedKeys.add(slotRowKey);

    final newTree = <TreeSliverNode<TreeItem>>[createTreeNode(state.experiment, expandedKeys)];
    final newState = state.copyWith(tree: newTree, treeVersion: state.treeVersion + 1);
    emit(newState);
  }

  void _onDeleteChild(DeleteTreeChild event, Emitter<EditorState> emit) {
    if (event.nodeId == state.experiment.nodeId) return;

    state.experiment.removeChild(event.nodeId);

    final expandedKeys = collectExpandedKeys(state.tree);
    final newTree = <TreeSliverNode<TreeItem>>[createTreeNode(state.experiment, expandedKeys)];
    final newState = state.copyWith(tree: newTree, treeVersion: state.treeVersion + 1);
    emit(newState);
  }

  void _onUpdateNodeData(UpdateTreeNodeData event, Emitter<EditorState> emit) {
    final updatedNode = event.nodeData;
    final newExperiment = state.experiment.copy() as Experiment;

    if (updatedNode.nodeId == newExperiment.nodeId) {
      newExperiment.updateFieldsFrom(updatedNode);
      final newState = state.copyWith(experiment: newExperiment);
      emit(newState);
      return;
    }

    final currentNode = newExperiment.find(updatedNode.nodeId);
    if (currentNode == null) {
      return;
    }

    currentNode.updateFieldsFrom(updatedNode);
    final newState = state.copyWith(experiment: newExperiment);
    emit(newState);
  }

  Map<String, dynamic> exportToJson() {
    return state.experiment.toJson();
  }
}
