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
      experiment: experiment ?? this.experiment.copy(),
      tree: tree ?? [...this.tree],
      treeVersion: treeVersion ?? this.treeVersion
    );
  }
}

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc({Experiment? experiment}) : super(_init(experiment)) {
    on<AddTreeChild>(_onAddChild);
    on<DeleteTreeChild>(_onDeleteChild);
    on<UpdateTreeNodeData>(_onUpdateNodeData);
  }

  static EditorState _init(Experiment? experiment) {
    final root = experiment ?? Experiment();
    final tree = <TreeSliverNode<TreeItem>>[createTreeNode(root, {})];
    return EditorState(experiment: root, tree: tree);
  }

  void _onAddChild(AddTreeChild event, Emitter<EditorState> emit) {
    final newExperiment = state.experiment.copy();

    final parent = newExperiment.find(event.parentId);
    if (parent == null || !parent.addChild(event.field, event.nodeType.emptyNode())) {
      return;
    }

    final expandedKeys = collectExpandedKeys(state.tree);
    expandedKeys.add("slot_${event.parentId}_${event.field}");

    final newTree = <TreeSliverNode<TreeItem>>[createTreeNode(newExperiment, expandedKeys)];
    final newState = state.copyWith(experiment: newExperiment, tree: newTree, treeVersion: state.treeVersion + 1);
    emit(newState);
  }

  void _onDeleteChild(DeleteTreeChild event, Emitter<EditorState> emit) {
    final newExperiment = state.experiment.copy();
    if (event.nodeId == newExperiment.nodeId || !newExperiment.removeChild(event.nodeId)) {
      return;
    }

    final expandedKeys = collectExpandedKeys(state.tree);
    final newTree = <TreeSliverNode<TreeItem>>[createTreeNode(newExperiment, expandedKeys)];
    final newState = state.copyWith(experiment: newExperiment, tree: newTree, treeVersion: state.treeVersion + 1);
    emit(newState);
  }

  void _onUpdateNodeData(UpdateTreeNodeData event, Emitter<EditorState> emit) {
    final updatedNode = event.nodeData;
    final newExperiment = state.experiment.copy();

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
}
